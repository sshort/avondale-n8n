-- Correct the Stage 3/4 raw-table lifecycle setup.
-- The lifecycle columns were added without defaults, so later full-refresh imports
-- reinserted NULL values. This migration sets the expected defaults and backfills
-- any current NULL rows.

BEGIN;

ALTER TABLE public.raw_members
    ALTER COLUMN first_seen_at SET DEFAULT now(),
    ALTER COLUMN last_seen_at SET DEFAULT now(),
    ALTER COLUMN is_current SET DEFAULT true;

UPDATE public.raw_members
SET
    first_seen_at = COALESCE(first_seen_at, now()),
    last_seen_at = COALESCE(last_seen_at, now()),
    is_current = COALESCE(is_current, true)
WHERE first_seen_at IS NULL
   OR last_seen_at IS NULL
   OR is_current IS NULL;

ALTER TABLE public.raw_contacts
    ALTER COLUMN first_seen_at SET DEFAULT now(),
    ALTER COLUMN last_seen_at SET DEFAULT now(),
    ALTER COLUMN is_current SET DEFAULT true;

UPDATE public.raw_contacts
SET
    first_seen_at = COALESCE(first_seen_at, now()),
    last_seen_at = COALESCE(last_seen_at, now()),
    is_current = COALESCE(is_current, true)
WHERE first_seen_at IS NULL
   OR last_seen_at IS NULL
   OR is_current IS NULL;

COMMIT;
