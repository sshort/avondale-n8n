CREATE OR REPLACE VIEW public.vw_signup_batch_clubspark_import_items AS
WITH venue_settings AS (
    SELECT max(gs.value) AS venue_slug
    FROM public.global_settings gs
    WHERE gs.key = 'clubspark_venue_slug'
)
SELECT
    q.id,
    q.batch_id,
    q.raw_member_id,
    q.member,
    q.email_address,
    q.source_membership,
    q.target_membership,
    q.status,
    q.notes,
    q.created_at,
    q.created_by,
    q.exported_at,
    q.imported_at,
    q.export_file_name,
    b.status AS batch_status,
    rm."Membership" AS current_membership,
    rm."Status" AS current_membership_status,
    rm."Payment" AS current_membership_payment,
    rm."Email address" AS raw_member_email,
    rm."Venue ID" AS venue_id,
    rm."British Tennis Number" AS british_tennis_number,
    target_pkg.category AS target_membership_category,
    target_pkg.season AS target_membership_season,
    target_pkg.display_order AS target_membership_display_order,
    source_pkg.category AS source_membership_category,
    source_pkg.season AS source_membership_season,
    target_map.clubspark_package_id,
    CASE
        WHEN target_map.clubspark_package_id IS NULL OR venue_settings.venue_slug IS NULL THEN NULL
        ELSE format(
            'https://clubspark.lta.org.uk/%s/Admin/Membership/Import?packageID=%s',
            venue_settings.venue_slug,
            target_map.clubspark_package_id::text
        )
    END AS clubspark_import_url
FROM public.signup_batch_clubspark_import_items q
JOIN public.signup_batches b
    ON b.id = q.batch_id
LEFT JOIN public.raw_members rm
    ON rm.id = q.raw_member_id
LEFT JOIN LATERAL (
    SELECT mp.category, mp.season, mp.display_order
    FROM public.membership_packages mp
    WHERE mp.name = q.target_membership
    ORDER BY mp.season DESC NULLS LAST, mp.display_order NULLS LAST, mp.cost DESC NULLS LAST
    LIMIT 1
) target_pkg ON TRUE
LEFT JOIN LATERAL (
    SELECT mp.category, mp.season
    FROM public.membership_packages mp
    WHERE mp.name = q.source_membership
    ORDER BY mp.season DESC NULLS LAST, mp.display_order NULLS LAST, mp.cost DESC NULLS LAST
    LIMIT 1
) source_pkg ON TRUE
LEFT JOIN public.clubspark_membership_import_targets target_map
    ON target_map.target_membership = q.target_membership
CROSS JOIN venue_settings;
