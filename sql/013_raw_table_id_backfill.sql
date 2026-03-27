-- Stage 3 of the raw table primary-key rollout.
-- Backfill local IDs and lifecycle fields, and prepare local defaults for future inserts.

BEGIN;

CREATE SEQUENCE IF NOT EXISTS public.raw_members_id_seq AS bigint;
ALTER SEQUENCE public.raw_members_id_seq OWNED BY public.raw_members.id;
ALTER TABLE public.raw_members
    ALTER COLUMN id SET DEFAULT nextval('public.raw_members_id_seq');

WITH numbered AS (
    SELECT
        ctid,
        row_number() OVER (
            ORDER BY
                COALESCE("Venue ID"::text, ''),
                COALESCE("British Tennis Number"::text, ''),
                COALESCE("First name"::text, ''),
                COALESCE("Last name"::text, ''),
                COALESCE("Membership"::text, ''),
                ctid
        ) AS rn
    FROM public.raw_members
    WHERE id IS NULL
),
base AS (
    SELECT COALESCE(max(id), 0) AS max_id
    FROM public.raw_members
)
UPDATE public.raw_members rm
SET id = base.max_id + numbered.rn
FROM numbered, base
WHERE rm.ctid = numbered.ctid;

UPDATE public.raw_members
SET
    first_seen_at = COALESCE(first_seen_at, now()),
    last_seen_at = COALESCE(last_seen_at, now()),
    is_current = COALESCE(is_current, true)
WHERE first_seen_at IS NULL
   OR last_seen_at IS NULL
   OR is_current IS NULL;

SELECT setval(
    'public.raw_members_id_seq',
    COALESCE((SELECT max(id)::bigint FROM public.raw_members), 1),
    COALESCE((SELECT max(id) FROM public.raw_members), 0) > 0
);

CREATE SEQUENCE IF NOT EXISTS public.raw_contacts_id_seq AS bigint;
ALTER SEQUENCE public.raw_contacts_id_seq OWNED BY public.raw_contacts.id;
ALTER TABLE public.raw_contacts
    ALTER COLUMN id SET DEFAULT nextval('public.raw_contacts_id_seq');

WITH numbered AS (
    SELECT
        ctid,
        row_number() OVER (
            ORDER BY
                COALESCE("Venue ID"::text, ''),
                COALESCE("Unique ID"::text, ''),
                COALESCE("British Tennis Number"::text, ''),
                COALESCE("First name"::text, ''),
                COALESCE("Last name"::text, ''),
                COALESCE("Email address"::text, ''),
                ctid
        ) AS rn
    FROM public.raw_contacts
    WHERE id IS NULL
),
base AS (
    SELECT COALESCE(max(id), 0) AS max_id
    FROM public.raw_contacts
)
UPDATE public.raw_contacts rc
SET id = base.max_id + numbered.rn
FROM numbered, base
WHERE rc.ctid = numbered.ctid;

UPDATE public.raw_contacts
SET
    first_seen_at = COALESCE(first_seen_at, now()),
    last_seen_at = COALESCE(last_seen_at, now()),
    is_current = COALESCE(is_current, true)
WHERE first_seen_at IS NULL
   OR last_seen_at IS NULL
   OR is_current IS NULL;

SELECT setval(
    'public.raw_contacts_id_seq',
    COALESCE((SELECT max(id)::bigint FROM public.raw_contacts), 1),
    COALESCE((SELECT max(id) FROM public.raw_contacts), 0) > 0
);

COMMIT;
