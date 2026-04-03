BEGIN;

-- Consolidated Team Roster View
-- Connects teams, players, and match logic for a complete team state display.
-- Used by the detail/roster table in AppSmith.
CREATE OR REPLACE VIEW public.vw_team_roster_consolidated AS
SELECT 
    t.id AS team_id,
    t.team_name,
    t.section,
    t.season,
    t.sort_order AS team_sort_order,
    tp.id AS team_player_id,
    tp.source_name,
    tp.is_captain,
    tp.sort_order AS player_sort_order,
    m.resolved_name,
    m.match_rule,
    m.category,
    m.status AS membership_status,
    m.self_email,
    m.self_phone,
    m.self_consent,
    m.main_contact_name,
    m.main_contact_email,
    m.main_contact_phone,
    m.match_ui_status
FROM public.teams t
LEFT JOIN public.team_players tp ON tp.team_id = t.id
LEFT JOIN public.vw_appsmith_team_player_matching m ON m.team_player_id = tp.id;

-- Team Management Dashboard View (lightweight)
-- Provides a high-level summary of teams for the AppSmith entry screen.
-- This avoids joining to the expensive matching view directly.
-- Instead, it only counts players and identifies captain info.
-- The ready_for_mailout flag uses the roster view for a single captain lookup.
DROP VIEW IF EXISTS public.vw_team_management_summary;
CREATE OR REPLACE VIEW public.vw_team_management_summary AS
WITH captain_info AS (
    SELECT DISTINCT ON (tp.team_id)
        tp.team_id,
        tp.source_name AS captain_name,
        m.match_ui_status AS captain_match_status,
        m.resolved_name AS captain_resolved_name,
        m.self_email AS captain_email
    FROM public.team_players tp
    LEFT JOIN public.vw_appsmith_team_player_matching m ON m.team_player_id = tp.id
    WHERE tp.is_captain = true
    ORDER BY tp.team_id, tp.id
)
SELECT 
    t.id AS team_id,
    t.team_name,
    t.section,
    t.season,
    t.sort_order,
    ci.captain_name,
    ci.captain_match_status,
    (SELECT COUNT(*) FROM public.team_players tp WHERE tp.team_id = t.id) AS player_count,
    CASE 
        WHEN ci.captain_email IS NOT NULL AND ci.captain_email != '' 
             AND ci.captain_resolved_name IS NOT NULL AND ci.captain_resolved_name != 'No Match'
        THEN true ELSE false 
    END AS ready_for_mailout
FROM public.teams t
LEFT JOIN captain_info ci ON ci.team_id = t.id;

COMMIT;
