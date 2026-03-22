ALTER TABLE public.membership_history
  ADD COLUMN IF NOT EXISTS "2026/2027" integer;

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
  ('Young Adult')
) AS v(membership)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.membership_history h
  WHERE h.membership = v.membership
);

WITH season_counts AS (
  SELECT
    p.season,
    p.category AS membership,
    COUNT(*)::integer AS count
  FROM public.raw_members m
  JOIN public.membership_packages p
    ON m."Membership" = p.name
  WHERE p.season IN ('2025', '2026')
    AND p.category <> 'Pavilion Key'
    AND m."Payment" IN ('Paid', 'Part Paid')
    AND m."Status" = 'Active'
  GROUP BY p.season, p.category
),
season_totals AS (
  SELECT
    season,
    'Total'::text AS membership,
    SUM(count)::integer AS count
  FROM season_counts
  GROUP BY season
),
all_counts AS (
  SELECT * FROM season_counts
  UNION ALL
  SELECT * FROM season_totals
)
UPDATE public.membership_history h
SET
  "2025/2026" = src_2025.count,
  "2026/2027" = src_2026.count
FROM
  (SELECT membership, count FROM all_counts WHERE season = '2025') AS src_2025
  FULL OUTER JOIN
  (SELECT membership, count FROM all_counts WHERE season = '2026') AS src_2026
    ON src_2025.membership = src_2026.membership
WHERE h.membership = COALESCE(src_2025.membership, src_2026.membership);
