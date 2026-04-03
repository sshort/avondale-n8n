BEGIN;

-- Enable the pg_trgm extension if not already present
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Add a GIST index to speed up similarity-based matching on member names.
-- This combined index covers the most common fuzzy matching target.
CREATE INDEX IF NOT EXISTS idx_raw_members_fuzzy_name_gist 
ON public.raw_members 
USING gist ((public.normalize_match_text("First name" || ' ' || m."Last name")) gist_trgm_ops)
WHERE COALESCE(is_current, true) = true AND "Status" = 'Active';

COMMIT;
