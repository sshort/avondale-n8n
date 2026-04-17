BEGIN;

ALTER TABLE public.cases
    DROP CONSTRAINT IF EXISTS cases_status_check;

ALTER TABLE public.cases
    ALTER COLUMN status SET DEFAULT 'New';

ALTER TABLE public.cases
    ADD CONSTRAINT cases_status_check
        CHECK (status IN ('New', 'In Progress', 'Waiting', 'Completed'));

COMMIT;
