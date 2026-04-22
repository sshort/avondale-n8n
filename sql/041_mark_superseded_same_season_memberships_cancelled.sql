BEGIN;

WITH normalized AS (
    SELECT
        rm.id,
        public.normalize_match_text(concat_ws(' ', rm."First name", rm."Last name")) AS norm_name,
        public.normalize_match_text(rm."Venue ID") AS norm_venue_id,
        public.normalize_match_text(rm."British Tennis Number") AS norm_btn,
        public.normalize_match_date(rm."Date of birth") AS norm_dob,
        public.normalize_match_email(rm."Email address") AS norm_email,
        COALESCE(
            public.normalize_match_phone(rm."Mobile number"),
            public.normalize_match_phone(rm."Phone number")
        ) AS norm_phone,
        public.normalize_match_postcode(rm."Postcode") AS norm_postcode,
        public.normalize_match_address_line1(rm."Address 1") AS norm_address_1,
        public.normalize_match_text(rm."Membership") AS norm_membership,
        NULLIF(substring(rm."Membership" from '(20[0-9]{2})'), '') AS membership_season,
        rm."Status",
        rm.last_seen_at
    FROM public.raw_members rm
),
superseded_rows AS (
    SELECT DISTINCT older.id
    FROM normalized older
    JOIN normalized newer
      ON newer.norm_name = older.norm_name
     AND newer.membership_season IS NOT NULL
     AND newer.membership_season = older.membership_season
     AND COALESCE(newer.norm_membership, '') <> COALESCE(older.norm_membership, '')
     AND COALESCE(newer.last_seen_at, '-infinity'::timestamptz) > COALESCE(older.last_seen_at, '-infinity'::timestamptz)
     AND (
        (older.norm_venue_id IS NOT NULL AND newer.norm_venue_id = older.norm_venue_id)
        OR (older.norm_btn IS NOT NULL AND newer.norm_btn = older.norm_btn)
        OR (older.norm_dob IS NOT NULL AND newer.norm_dob = older.norm_dob)
        OR (older.norm_email IS NOT NULL AND newer.norm_email = older.norm_email)
        OR (older.norm_phone IS NOT NULL AND newer.norm_phone = older.norm_phone)
        OR (
            older.norm_postcode IS NOT NULL
            AND older.norm_address_1 IS NOT NULL
            AND newer.norm_postcode = older.norm_postcode
            AND newer.norm_address_1 = older.norm_address_1
        )
     )
    WHERE older.membership_season IS NOT NULL
      AND COALESCE(older."Status", '') <> 'Cancelled'
)
UPDATE public.raw_members rm
SET "Status" = 'Cancelled'
FROM superseded_rows sr
WHERE rm.id = sr.id;

COMMIT;
