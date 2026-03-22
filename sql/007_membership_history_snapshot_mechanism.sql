CREATE TABLE IF NOT EXISTS public.membership_history_snapshots (
  id bigserial PRIMARY KEY,
  snapshot_key text NOT NULL,
  source_season text NOT NULL,
  membership text NOT NULL,
  member_count integer NOT NULL,
  captured_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (snapshot_key, membership)
);

CREATE INDEX IF NOT EXISTS idx_membership_history_snapshots_lookup
  ON public.membership_history_snapshots (snapshot_key);

CREATE OR REPLACE FUNCTION public.capture_membership_history_snapshot(
  p_snapshot_key text,
  p_source_season text DEFAULT NULL
)
RETURNS TABLE (
  snapshot_key text,
  source_season text,
  rows_written integer,
  updated_membership_history boolean
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_snapshot_key text := trim(coalesce(p_snapshot_key, ''));
  v_source_season text := trim(coalesce(p_source_season, ''));
  v_rows_written integer := 0;
BEGIN
  IF v_snapshot_key = '' THEN
    RAISE EXCEPTION 'snapshot_key is required';
  END IF;

  IF v_source_season = '' AND v_snapshot_key ~ '^\d{4}/\d{4}$' THEN
    v_source_season := split_part(v_snapshot_key, '/', 1);
  END IF;

  IF v_source_season = '' THEN
    RAISE EXCEPTION 'source_season is required';
  END IF;

  UPDATE public.membership_history
  SET membership = 'Honorary'
  WHERE membership = 'Senior - honorary';

  UPDATE public.membership_history
  SET membership = 'Student At Home'
  WHERE membership = 'Student at home';

  UPDATE public.membership_history
  SET membership = 'Student Away'
  WHERE membership = 'Student away from home';

  INSERT INTO public.membership_history (membership)
  SELECT v.membership
  FROM (VALUES
    ('Family'),
    ('Senior Junior'),
    ('Mini (U10)'),
    ('Parent'),
    ('Young Adult'),
    ('Total')
  ) AS v(membership)
  WHERE NOT EXISTS (
    SELECT 1
    FROM public.membership_history h
    WHERE h.membership = v.membership
  );

  WITH season_counts AS (
    SELECT
      p.category AS membership,
      COUNT(*)::integer AS member_count
    FROM public.raw_members m
    JOIN public.membership_packages p
      ON m."Membership" = p.name
    WHERE p.season = v_source_season
      AND p.category <> 'Pavilion Key'
      AND m."Payment" IN ('Paid', 'Part Paid')
      AND m."Status" = 'Active'
    GROUP BY p.category
  ),
  total_row AS (
    SELECT
      'Total'::text AS membership,
      COALESCE(SUM(member_count), 0)::integer AS member_count
    FROM season_counts
  ),
  snapshot_rows AS (
    SELECT * FROM season_counts
    UNION ALL
    SELECT * FROM total_row
  ),
  upserted AS (
    INSERT INTO public.membership_history_snapshots (
      snapshot_key,
      source_season,
      membership,
      member_count
    )
    SELECT
      v_snapshot_key,
      v_source_season,
      sr.membership,
      sr.member_count
    FROM snapshot_rows sr
    ON CONFLICT ON CONSTRAINT membership_history_snapshots_snapshot_key_membership_key
    DO UPDATE SET
      source_season = EXCLUDED.source_season,
      member_count = EXCLUDED.member_count,
      captured_at = now()
    RETURNING 1
  )
  SELECT COUNT(*)::integer INTO v_rows_written
  FROM upserted;

  IF v_snapshot_key ~ '^\d{4}/\d{4}$' THEN
    EXECUTE format(
      'ALTER TABLE public.membership_history ADD COLUMN IF NOT EXISTS %I integer',
      v_snapshot_key
    );

    EXECUTE format(
      'UPDATE public.membership_history h
       SET %1$I = s.member_count
       FROM public.membership_history_snapshots s
       WHERE s.snapshot_key = %2$L
         AND h.membership = s.membership',
      v_snapshot_key,
      v_snapshot_key
    );
  END IF;

  RETURN QUERY
  SELECT
    v_snapshot_key,
    v_source_season,
    v_rows_written,
    true;
END;
$$;
