BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.cases (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    title text NOT NULL,
    contact_name text NOT NULL,
    contact_email text,
    contact_phone text,
    source text NOT NULL DEFAULT 'manual',
    status text NOT NULL DEFAULT 'In Progress'
        CHECK (status IN ('In Progress', 'Waiting', 'Completed')),
    priority text NOT NULL DEFAULT 'Medium'
        CHECK (priority IN ('Low', 'Medium', 'High', 'Urgent')),
    notes text,
    last_inbound_at timestamptz,
    last_outbound_at timestamptz,
    closed_at timestamptz,
    created_by text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.case_emails (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    case_id uuid NOT NULL REFERENCES public.cases(id) ON DELETE CASCADE,
    direction text NOT NULL
        CHECK (direction IN ('incoming', 'outgoing', 'note')),
    subject text,
    body_html text,
    body_text text,
    recipients jsonb NOT NULL DEFAULT '{}'::jsonb,
    template_key text,
    signature_template_key text,
    delivery_mode text,
    gmail_message_id text,
    gmail_thread_id text,
    created_by text,
    sent_at timestamptz,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cases_status
    ON public.cases (status);

CREATE INDEX IF NOT EXISTS idx_cases_priority
    ON public.cases (priority);

CREATE INDEX IF NOT EXISTS idx_cases_updated_at
    ON public.cases (updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_cases_contact_email
    ON public.cases (contact_email);

CREATE INDEX IF NOT EXISTS idx_case_emails_case_id_created_at
    ON public.case_emails (case_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_case_emails_case_id_sent_at
    ON public.case_emails (case_id, sent_at DESC);

CREATE INDEX IF NOT EXISTS idx_case_emails_direction
    ON public.case_emails (direction);

CREATE INDEX IF NOT EXISTS idx_case_emails_gmail_message_id
    ON public.case_emails (gmail_message_id);

COMMIT;
