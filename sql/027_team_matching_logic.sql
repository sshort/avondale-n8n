BEGIN;

CREATE OR REPLACE VIEW public.vw_appsmith_team_player_matching AS
WITH base_players AS (
    SELECT 
        tp.id AS team_player_id,
        tp.team_id,
        t.team_name,
        t.season,
        tp.source_name,
        public.normalize_match_text(tp.source_name) AS norm_source_name,
        tp.is_captain,
        tp.sort_order
    FROM public.team_players tp
    JOIN public.teams t ON t.id = tp.team_id
),
exact_matches AS (
    -- Group 1: Exact matches in raw_members (Active, non-social)
    SELECT 
        bp.team_player_id,
        m.id AS member_id,
        'Exact Member' AS match_rule,
        1 AS match_priority,
        m."First name" || ' ' || m."Last name" AS resolved_name,
        m."Email address" AS email,
        COALESCE(m."Mobile number", m."Phone number") AS phone,
        m."Membership" AS category,
        m."Status" AS status,
        m."Share Contact Detail" AS consent
    FROM base_players bp
    JOIN public.raw_members m 
      ON public.normalize_match_text(m."First name" || ' ' || m."Last name") = bp.norm_source_name
     AND COALESCE(m.is_current, true) = true
     AND m."Status" = 'Active'
),
override_matches AS (
    -- Group 2a: Full Name Overrides
    SELECT 
        bp.team_player_id,
        m.id AS member_id,
        'Override (Full)' AS match_rule,
        2 AS match_priority,
        m."First name" || ' ' || m."Last name" AS resolved_name,
        m."Email address" AS email,
        COALESCE(m."Mobile number", m."Phone number") AS phone,
        m."Membership" AS category,
        m."Status" AS status,
        m."Share Contact Detail" AS consent
    FROM base_players bp
    JOIN public.team_name_overrides o ON public.normalize_match_text(o.source) = bp.norm_source_name
    JOIN public.raw_members m 
      ON public.normalize_match_text(m."First name" || ' ' || m."Last name") = public.normalize_match_text(o.target)
     AND COALESCE(m.is_current, true) = true
     AND m."Status" = 'Active'
),
nickname_matches AS (
    -- Group 2b: First Name Nickname Matches (e.g. Kat Rogers -> Katherine Rogers)
    -- Splits source_name and looks for overrides on the FIRST part only.
    -- Handles multi-part last names (e.g. "Jackie Sinclair Brown" -> "Jacqueline Sinclair Brown")
    SELECT 
        bp.team_player_id,
        m.id AS member_id,
        'Nickname' AS match_rule,
        2 AS match_priority,
        m."First name" || ' ' || m."Last name" AS resolved_name,
        m."Email address" AS email,
        COALESCE(m."Mobile number", m."Phone number") AS phone,
        m."Membership" AS category,
        m."Status" AS status,
        m."Share Contact Detail" AS consent
    FROM base_players bp
    JOIN public.team_name_overrides o 
      ON public.normalize_match_text(o.source) = public.normalize_match_text(split_part(bp.norm_source_name, ' ', 1))
    JOIN public.raw_members m 
      ON public.normalize_match_text(m."First name") = public.normalize_match_text(o.target)
      -- Match everything after the first space as the last name
     AND public.normalize_match_text(m."Last name") = public.normalize_match_text(substring(bp.norm_source_name from '\s+(.*)$'))
     AND COALESCE(m.is_current, true) = true
     AND m."Status" = 'Active'
     WHERE bp.source_name LIKE '% %'
),
contact_only_matches AS (
    -- Group 3: Contact-only matches (Not signed up this year)
    SELECT 
        bp.team_player_id,
        NULL::bigint AS member_id,
        'Not Signed Up' AS match_rule,
        3 AS match_priority,
        c.first_name || ' ' || c.last_name AS resolved_name,
        c.email_address AS email,
        COALESCE(c.mobile_number, c.phone_number) AS phone,
        'Contact Only' AS category,
        c.member_status AS status,
        rc."Share Contact Detail" AS consent
    FROM base_players bp
    JOIN public.vw_best_current_contacts c ON c.norm_name = bp.norm_source_name
    LEFT JOIN public.raw_contacts rc ON rc.id = c.contact_id
),
fuzzy_matches AS (
    -- Group 4: Fuzzy matches (Similarity >= 0.7)
    SELECT 
        bp.team_player_id,
        m.id AS member_id,
        'Fuzzy (' || round(similarity(public.normalize_match_text(m."First name" || ' ' || m."Last name"), bp.norm_source_name)::numeric, 2) || ')' AS match_rule,
        4 AS match_priority,
        m."First name" || ' ' || m."Last name" AS resolved_name,
        m."Email address" AS email,
        COALESCE(m."Mobile number", m."Phone number") AS phone,
        m."Membership" AS category,
        m."Status" AS status,
        m."Share Contact Detail" AS consent
    FROM base_players bp
    CROSS JOIN (
        SELECT id, "First name", "Last name", "Email address", "Mobile number", "Phone number", "Membership", "Status", "Share Contact Detail"
        FROM public.raw_members 
        WHERE COALESCE(is_current, true) = true AND "Status" = 'Active'
    ) m
    WHERE similarity(public.normalize_match_text(m."First name" || ' ' || m."Last name"), bp.norm_source_name) >= 0.7
),
all_candidates AS (
    SELECT * FROM exact_matches
    UNION ALL
    SELECT * FROM override_matches
    UNION ALL
    SELECT * FROM nickname_matches
    UNION ALL
    SELECT * FROM contact_only_matches
    UNION ALL
    SELECT * FROM fuzzy_matches
),
ranked_candidates AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY team_player_id ORDER BY match_priority ASC, resolved_name ASC) AS rn
    FROM all_candidates
),
junior_parents AS (
    SELECT 
        j.member_raw_id,
        j.main_contact_name,
        j.main_contact_email,
        COALESCE(j.main_contact_mobile, j.main_contact_phone) AS main_contact_phone,
        j.match_confidence
    FROM public.vw_junior_main_contacts j
    WHERE j.match_confidence = 'high'
)
SELECT 
    bp.team_player_id,
    bp.team_id,
    bp.team_name,
    bp.season,
    bp.source_name,
    bp.is_captain,
    bp.sort_order,
    COALESCE(rc.resolved_name, 'No Match') AS resolved_name,
    rc.match_rule,
    rc.category,
    rc.status,
    rc.email AS self_email,
    rc.phone AS self_phone,
    rc.consent AS self_consent,
    jp.main_contact_name,
    jp.main_contact_email,
    jp.main_contact_phone,
    CASE 
        WHEN rc.resolved_name IS NULL THEN 'danger'
        WHEN rc.match_rule = 'Exact Member' THEN 'success'
        WHEN rc.match_rule IN ('Override (Full)', 'Nickname') THEN 'info'
        WHEN rc.match_rule = 'Not Signed Up' THEN 'warning'
        ELSE 'primary'
    END AS match_ui_status
FROM base_players bp
LEFT JOIN ranked_candidates rc ON rc.team_player_id = bp.team_player_id AND rc.rn = 1
LEFT JOIN junior_parents jp ON jp.member_raw_id = rc.member_id;

COMMIT;
