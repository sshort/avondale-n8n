BEGIN;

ALTER TABLE public.case_emails
    ADD COLUMN IF NOT EXISTS internet_message_id text,
    ADD COLUMN IF NOT EXISTS in_reply_to_message_id text,
    ADD COLUMN IF NOT EXISTS references_header text,
    ADD COLUMN IF NOT EXISTS parent_case_email_id uuid REFERENCES public.case_emails(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS open_tracking_token text,
    ADD COLUMN IF NOT EXISTS open_tracking_enabled boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS open_tracking_status text NOT NULL DEFAULT 'Not Tracked',
    ADD COLUMN IF NOT EXISTS first_opened_at timestamptz,
    ADD COLUMN IF NOT EXISTS last_opened_at timestamptz,
    ADD COLUMN IF NOT EXISTS open_count integer NOT NULL DEFAULT 0;

ALTER TABLE public.case_emails
    DROP CONSTRAINT IF EXISTS case_emails_open_tracking_status_check;

ALTER TABLE public.case_emails
    ADD CONSTRAINT case_emails_open_tracking_status_check
        CHECK (open_tracking_status IN ('Not Tracked', 'Not Opened', 'Opened'));

UPDATE public.case_emails
SET
    internet_message_id = COALESCE(
        NULLIF(btrim(internet_message_id), ''),
        NULLIF(btrim(metadata ->> 'message_id_header'), ''),
        NULLIF(btrim(metadata ->> 'internet_message_id'), '')
    ),
    in_reply_to_message_id = COALESCE(
        NULLIF(btrim(in_reply_to_message_id), ''),
        NULLIF(btrim(metadata ->> 'in_reply_to_message_id'), ''),
        NULLIF(btrim(metadata ->> 'in_reply_to'), '')
    ),
    references_header = COALESCE(
        NULLIF(btrim(references_header), ''),
        NULLIF(btrim(metadata ->> 'references_header'), ''),
        NULLIF(btrim(metadata ->> 'references'), '')
    )
WHERE
    COALESCE(internet_message_id, '') = ''
    OR COALESCE(in_reply_to_message_id, '') = ''
    OR COALESCE(references_header, '') = '';

UPDATE public.case_emails
SET
    internet_message_id = NULLIF(btrim(internet_message_id), ''),
    in_reply_to_message_id = NULLIF(btrim(in_reply_to_message_id), ''),
    references_header = NULLIF(btrim(regexp_replace(COALESCE(references_header, ''), '\s+', ' ', 'g')), ''),
    open_tracking_token = NULLIF(btrim(open_tracking_token), ''),
    open_count = GREATEST(COALESCE(open_count, 0), 0),
    open_tracking_status = CASE
        WHEN COALESCE(open_count, 0) > 0 OR first_opened_at IS NOT NULL OR last_opened_at IS NOT NULL THEN 'Opened'
        WHEN COALESCE(open_tracking_enabled, false) THEN 'Not Opened'
        ELSE 'Not Tracked'
    END,
    first_opened_at = CASE
        WHEN first_opened_at IS NOT NULL THEN first_opened_at
        WHEN last_opened_at IS NOT NULL THEN last_opened_at
        ELSE NULL
    END,
    last_opened_at = CASE
        WHEN COALESCE(open_count, 0) > 0 AND last_opened_at IS NULL THEN COALESCE(first_opened_at, created_at, sent_at)
        ELSE last_opened_at
    END;

WITH ranked_duplicates AS (
    SELECT
        id,
        internet_message_id,
        row_number() OVER (
            PARTITION BY internet_message_id
            ORDER BY COALESCE(sent_at, created_at) ASC, created_at ASC, id ASC
        ) AS rn
    FROM public.case_emails
    WHERE internet_message_id IS NOT NULL
)
UPDATE public.case_emails AS ce
SET
    metadata = COALESCE(ce.metadata, '{}'::jsonb)
        || jsonb_build_object(
            'duplicate_internet_message_id_original',
            ce.internet_message_id,
            'duplicate_internet_message_id_replaced_at',
            now()
        ),
    internet_message_id = NULL
FROM ranked_duplicates AS dup
WHERE ce.id = dup.id
  AND dup.rn > 1;

CREATE UNIQUE INDEX IF NOT EXISTS uq_case_emails_internet_message_id
    ON public.case_emails (internet_message_id)
    WHERE internet_message_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_case_emails_in_reply_to_message_id
    ON public.case_emails (in_reply_to_message_id)
    WHERE in_reply_to_message_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_case_emails_parent_case_email_id
    ON public.case_emails (parent_case_email_id)
    WHERE parent_case_email_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_case_emails_open_tracking_token
    ON public.case_emails (open_tracking_token)
    WHERE open_tracking_token IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_case_emails_open_tracking_status
    ON public.case_emails (open_tracking_status);

COMMIT;
