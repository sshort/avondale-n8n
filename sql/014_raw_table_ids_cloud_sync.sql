-- Stage 4 of the raw table primary-key rollout.
-- Prepare the cloud raw tables to accept local IDs and lifecycle fields during sync.
-- This file is safe to run repeatedly.

BEGIN;

ALTER TABLE public.raw_members
    ADD COLUMN IF NOT EXISTS id bigint,
    ADD COLUMN IF NOT EXISTS first_seen_at timestamptz,
    ADD COLUMN IF NOT EXISTS last_seen_at timestamptz,
    ADD COLUMN IF NOT EXISTS is_current boolean;

ALTER TABLE public.raw_contacts
    ADD COLUMN IF NOT EXISTS id bigint,
    ADD COLUMN IF NOT EXISTS first_seen_at timestamptz,
    ADD COLUMN IF NOT EXISTS last_seen_at timestamptz,
    ADD COLUMN IF NOT EXISTS is_current boolean;

CREATE SEQUENCE IF NOT EXISTS public.raw_members_id_seq AS bigint;
ALTER SEQUENCE public.raw_members_id_seq OWNED BY public.raw_members.id;
ALTER TABLE public.raw_members
    ALTER COLUMN id SET DEFAULT nextval('public.raw_members_id_seq');

CREATE SEQUENCE IF NOT EXISTS public.raw_contacts_id_seq AS bigint;
ALTER SEQUENCE public.raw_contacts_id_seq OWNED BY public.raw_contacts.id;
ALTER TABLE public.raw_contacts
    ALTER COLUMN id SET DEFAULT nextval('public.raw_contacts_id_seq');

COMMIT;
