-- Stage 2 of the raw table primary-key rollout.
-- Add non-breaking nullable lifecycle columns to the current raw tables only.
-- Do not add primary keys, defaults, or identity generation yet.

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
