BEGIN;

CREATE OR REPLACE FUNCTION public.run_member_contact_matching_regression_checks()
RETURNS TABLE (
    check_name text,
    ok boolean,
    expected text,
    actual text
)
LANGUAGE sql
STABLE
AS $$
    WITH checks AS (
        SELECT
            'graham_family_prefers_household_contact'::text AS check_name,
            (
                r.contact_id = 4184
                AND r.payer_name = 'Hamish Graham'
                AND r.email_address = 'hamish.graham@outlook.com'
                AND r.postcode = 'GU52 8UH'
                AND r.resolve_rule = 'family_active_adult_address'
            ) AS ok,
            'contact_id=4184 payer=Hamish Graham rule=family_active_adult_address postcode=GU52 8UH'::text AS expected,
            format(
                'contact_id=%s payer=%s rule=%s postcode=%s',
                coalesce(r.contact_id::text, 'NULL'),
                coalesce(r.payer_name, 'NULL'),
                coalesce(r.resolve_rule, 'NULL'),
                coalesce(r.postcode, 'NULL')
            ) AS actual
        FROM public.resolve_best_contact_row('Louise Graham', 'lugraham15@gmail.com', 'Graham', true) r

        UNION ALL

        SELECT
            'roni_asp_exact_name_single_match',
            (
                r.contact_id = 3717
                AND r.email_address = 'roniasp6@gmail.com'
                AND r.resolve_rule = 'exact_name_email'
                AND r.candidate_count = 1
            ) AS ok,
            'contact_id=3717 email=roniasp6@gmail.com rule=exact_name_email candidate_count=1',
            format(
                'contact_id=%s email=%s rule=%s candidate_count=%s',
                coalesce(r.contact_id::text, 'NULL'),
                coalesce(r.email_address, 'NULL'),
                coalesce(r.resolve_rule, 'NULL'),
                coalesce(r.candidate_count::text, 'NULL')
            )
        FROM public.resolve_best_contact_row('Roni Asp', 'roniasp6@gmail.com', 'Asp', false) r

        UNION ALL

        SELECT
            'david_smith_kyrenia_email_distinguishes_duplicate',
            (
                r.contact_id = 4705
                AND r.email_address = 'dave.smith@kyrenia.co.uk'
                AND r.resolve_rule = 'exact_name_email'
            ) AS ok,
            'contact_id=4705 email=dave.smith@kyrenia.co.uk rule=exact_name_email',
            format(
                'contact_id=%s email=%s rule=%s',
                coalesce(r.contact_id::text, 'NULL'),
                coalesce(r.email_address, 'NULL'),
                coalesce(r.resolve_rule, 'NULL')
            )
        FROM public.resolve_best_contact_row('David Smith', 'dave.smith@kyrenia.co.uk', 'Smith', false) r

        UNION ALL

        SELECT
            'david_smith_ntl_email_distinguishes_duplicate',
            (
                r.contact_id = 4710
                AND r.email_address = 'd.smith44@ntlworld.com'
                AND r.resolve_rule = 'exact_name_email'
            ) AS ok,
            'contact_id=4710 email=d.smith44@ntlworld.com rule=exact_name_email',
            format(
                'contact_id=%s email=%s rule=%s',
                coalesce(r.contact_id::text, 'NULL'),
                coalesce(r.email_address, 'NULL'),
                coalesce(r.resolve_rule, 'NULL')
            )
        FROM public.resolve_best_contact_row('David Smith', 'd.smith44@ntlworld.com', 'Smith', false) r

        UNION ALL

        SELECT
            'david_smith_current_member_rows_stay_distinct',
            (
                count(*) = 2
                AND count(DISTINCT nullif(trim("British Tennis Number"), '')) = 2
                AND count(DISTINCT lower(trim("Email address"))) = 2
            ) AS ok,
            'rows=2 distinct_btn=2 distinct_email=2',
            format(
                'rows=%s distinct_btn=%s distinct_email=%s',
                count(*),
                count(DISTINCT nullif(trim("British Tennis Number"), '')),
                count(DISTINCT lower(trim("Email address")))
            )
        FROM public.raw_members
        WHERE trim(concat_ws(' ', "First name", "Last name")) = 'David Smith'
          AND "Membership" = '1. Senior 2026'
          AND coalesce(is_current, true) = true
    )
    SELECT check_name, ok, expected, actual
    FROM checks
    ORDER BY check_name;
$$;

CREATE OR REPLACE VIEW public.vw_member_contact_matching_regression_checks AS
SELECT *
FROM public.run_member_contact_matching_regression_checks();

COMMIT;
