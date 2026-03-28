BEGIN;

CREATE OR REPLACE VIEW public.vw_best_current_contacts AS
SELECT
    rc.id AS contact_id,
    trim(concat_ws(' ', rc."First name", rc."Last name")) AS payer_name,
    NULLIF(trim(rc."First name"), '') AS first_name,
    NULLIF(trim(rc."Last name"), '') AS last_name,
    NULLIF(trim(rc."Email address"), '') AS email_address,
    NULLIF(trim(rc."Phone number"), '') AS phone_number,
    NULLIF(trim(rc."Mobile number"), '') AS mobile_number,
    NULLIF(trim(rc."Address 1"), '') AS address_1,
    NULLIF(trim(rc."Address 2"), '') AS address_2,
    NULLIF(trim(rc."Address 3"), '') AS address_3,
    NULLIF(trim(rc.town), '') AS town,
    NULLIF(trim(rc.county), '') AS county,
    NULLIF(trim(rc.postcode), '') AS postcode,
    NULLIF(trim(rc."Venue ID"), '') AS venue_id,
    NULLIF(trim(rc."Member status"), '') AS member_status,
    public.normalize_match_text(concat_ws(' ', rc."First name", rc."Last name")) AS norm_name,
    public.normalize_match_text(rc."Last name") AS norm_last_name,
    public.normalize_match_email(rc."Email address") AS norm_email,
    public.normalize_match_date(rc.created) AS created_date,
    (
        CASE WHEN public.normalize_match_address_line1(rc."Address 1") IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN public.normalize_match_postcode(rc.postcode) IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN public.normalize_match_email(rc."Email address") IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN COALESCE(public.normalize_match_phone(rc."Mobile number"), public.normalize_match_phone(rc."Phone number")) IS NOT NULL THEN 1 ELSE 0 END +
        CASE WHEN public.normalize_match_date(rc."Date of birth") IS NOT NULL THEN 1 ELSE 0 END
    ) AS quality_score,
    CASE COALESCE(NULLIF(trim(rc."Member status"), ''), '')
        WHEN 'Active Member' THEN 0
        WHEN 'Non Member' THEN 1
        WHEN 'Lapsed Member' THEN 2
        ELSE 3
    END AS status_rank,
    CASE
        WHEN COALESCE(NULLIF(trim(rc."Address 1"), ''), NULLIF(trim(rc.postcode), '')) IS NOT NULL
        THEN 0 ELSE 1
    END AS address_rank,
    CASE WHEN NULLIF(trim(rc."Email address"), '') IS NOT NULL THEN 0 ELSE 1 END AS email_rank,
    CASE
        WHEN COALESCE(NULLIF(trim(rc."Mobile number"), ''), NULLIF(trim(rc."Phone number"), '')) IS NOT NULL
        THEN 0 ELSE 1
    END AS phone_rank,
    CASE COALESCE(NULLIF(trim(rc.junior), ''), 'No')
        WHEN 'No' THEN 0
        ELSE 1
    END AS junior_rank
FROM public.raw_contacts rc
WHERE COALESCE(rc.is_current, true) = true;

CREATE OR REPLACE FUNCTION public.resolve_best_contact_row(
    p_member_name text,
    p_member_email text DEFAULT NULL,
    p_member_last_name text DEFAULT NULL,
    p_is_family boolean DEFAULT false
)
RETURNS TABLE (
    contact_id bigint,
    payer_name text,
    first_name text,
    last_name text,
    email_address text,
    phone_number text,
    mobile_number text,
    address_1 text,
    address_2 text,
    address_3 text,
    town text,
    county text,
    postcode text,
    venue_id text,
    member_status text,
    resolve_rule text,
    candidate_count integer
)
LANGUAGE sql
STABLE
AS $$
    WITH params AS (
        SELECT
            public.normalize_match_text(p_member_name) AS norm_name,
            public.normalize_match_email(p_member_email) AS norm_email,
            public.normalize_match_text(p_member_last_name) AS norm_last_name,
            COALESCE(p_is_family, false) AS is_family
    ),
    candidates AS (
        SELECT
            c.contact_id,
            c.payer_name,
            c.first_name,
            c.last_name,
            c.email_address,
            c.phone_number,
            c.mobile_number,
            c.address_1,
            c.address_2,
            c.address_3,
            c.town,
            c.county,
            c.postcode,
            c.venue_id,
            c.member_status,
            CASE
                WHEN p.is_family
                 AND p.norm_last_name IS NOT NULL
                 AND c.norm_last_name = p.norm_last_name
                 AND c.status_rank = 0
                 AND c.junior_rank = 0
                 AND c.address_rank = 0
                THEN 0
                WHEN p.norm_name IS NOT NULL
                 AND p.norm_email IS NOT NULL
                 AND c.norm_name = p.norm_name
                 AND c.norm_email = p.norm_email
                 AND NOT p.is_family
                THEN 1
                WHEN p.norm_name IS NOT NULL
                 AND c.norm_name = p.norm_name
                 AND NOT p.is_family
                THEN 2
                WHEN p.is_family
                 AND p.norm_last_name IS NOT NULL
                 AND c.norm_last_name = p.norm_last_name
                 AND c.address_rank = 0
                THEN 3
                WHEN p.norm_name IS NOT NULL
                 AND c.norm_name = p.norm_name
                THEN 4
                WHEN p.norm_email IS NOT NULL
                 AND c.norm_email = p.norm_email
                THEN 5
                WHEN p.is_family
                 AND p.norm_last_name IS NOT NULL
                 AND c.norm_last_name = p.norm_last_name
                THEN 6
                ELSE 9
            END AS resolver_rank,
            CASE
                WHEN p.is_family
                 AND p.norm_last_name IS NOT NULL
                 AND c.norm_last_name = p.norm_last_name
                 AND c.status_rank = 0
                 AND c.junior_rank = 0
                 AND c.address_rank = 0
                THEN 'family_active_adult_address'
                WHEN p.norm_name IS NOT NULL
                 AND p.norm_email IS NOT NULL
                 AND c.norm_name = p.norm_name
                 AND c.norm_email = p.norm_email
                 AND NOT p.is_family
                THEN 'exact_name_email'
                WHEN p.norm_name IS NOT NULL
                 AND c.norm_name = p.norm_name
                 AND NOT p.is_family
                THEN 'exact_name'
                WHEN p.is_family
                 AND p.norm_last_name IS NOT NULL
                 AND c.norm_last_name = p.norm_last_name
                 AND c.address_rank = 0
                THEN 'family_last_name_address'
                WHEN p.norm_name IS NOT NULL
                 AND c.norm_name = p.norm_name
                THEN 'exact_name'
                WHEN p.norm_email IS NOT NULL
                 AND c.norm_email = p.norm_email
                THEN 'email'
                WHEN p.is_family
                 AND p.norm_last_name IS NOT NULL
                 AND c.norm_last_name = p.norm_last_name
                THEN 'family_last_name'
                ELSE 'fallback'
            END AS resolve_rule,
            c.address_rank,
            c.email_rank,
            c.phone_rank,
            c.quality_score,
            c.status_rank,
            c.junior_rank,
            c.created_date
        FROM public.vw_best_current_contacts c
        CROSS JOIN params p
        WHERE (
            p.norm_name IS NOT NULL
            AND c.norm_name = p.norm_name
        ) OR (
            p.norm_email IS NOT NULL
            AND c.norm_email = p.norm_email
        ) OR (
            p.is_family
            AND p.norm_last_name IS NOT NULL
            AND c.norm_last_name = p.norm_last_name
        )
    )
    SELECT
        contact_id,
        payer_name,
        first_name,
        last_name,
        email_address,
        phone_number,
        mobile_number,
        address_1,
        address_2,
        address_3,
        town,
        county,
        postcode,
        venue_id,
        member_status,
        resolve_rule,
        COUNT(*) OVER ()::integer AS candidate_count
    FROM candidates
    ORDER BY
        resolver_rank ASC,
        address_rank ASC,
        email_rank ASC,
        phone_rank ASC,
        quality_score DESC,
        status_rank ASC,
        junior_rank ASC,
        created_date DESC NULLS LAST,
        payer_name,
        contact_id
    LIMIT 1;
$$;

CREATE OR REPLACE VIEW public.vw_signup_batch_items AS
WITH signup_rows AS (
    SELECT
        s.id AS source_id,
        s.batch_id,
        s.signup_date AS item_date,
        s.member,
        s.payer,
        s.product,
        COALESCE(NULLIF(trim(s.email_address), ''), NULLIF(trim(m."Email address"), '')) AS resolver_email,
        NULLIF(regexp_replace(s.payer, '^\S+\s*', ''), '') AS payer_last_name,
        COALESCE(NULLIF(trim(s.source), ''), 'email_capture') AS source
    FROM public.member_signups s
    LEFT JOIN public.raw_members m
        ON s.member = concat(m."First name", ' ', m."Last name")
       AND m."Membership" = s.product
       AND COALESCE(m.is_current, true) = true
)
SELECT
    s.source_id,
    s.batch_id,
    s.item_date,
    s.member,
    s.payer,
    s.product,
    COALESCE(NULLIF(trim(bc.email_address), ''), NULLIF(trim(s.resolver_email), '')) AS email_address,
    bc.address_1,
    bc.address_2,
    bc.address_3,
    bc.town,
    bc.postcode,
    CASE
        WHEN s.product NOT IN ('6. Parent 2026', 'b. Pavilion Key', 'a. Social 2026')
        THEN 1 ELSE 0
    END AS regular_tags,
    CASE WHEN s.product = '6. Parent 2026' THEN 1 ELSE 0 END AS parent_tags,
    CASE WHEN s.product = 'b. Pavilion Key' THEN 1 ELSE 0 END AS key_tags,
    s.source,
    NULL::text AS notes,
    'member_signups'::text AS source_table
FROM signup_rows s
LEFT JOIN LATERAL public.resolve_best_contact_row(
    s.payer,
    s.resolver_email,
    s.payer_last_name,
    false
) bc ON TRUE

UNION ALL

SELECT
    mi.id AS source_id,
    mi.batch_id,
    mi.created_at AS item_date,
    mi.member,
    mi.payer,
    NULL::text AS product,
    mi.email_address,
    mi.address_1,
    mi.address_2,
    mi.address_3,
    mi.town,
    mi.postcode,
    mi.regular_tags,
    mi.parent_tags,
    mi.key_tags,
    mi.source,
    mi.notes,
    'signup_batch_manual_items'::text AS source_table
FROM public.signup_batch_manual_items mi;

COMMIT;
