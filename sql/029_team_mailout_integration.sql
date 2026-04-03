BEGIN;

-- CRUD: Add a player to a team
CREATE OR REPLACE FUNCTION public.fn_add_team_player(
    p_team_id bigint,
    p_source_name text,
    p_is_captain boolean DEFAULT false,
    p_sort_order integer DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    v_id bigint;
    v_next_order integer;
BEGIN
    IF p_sort_order IS NULL THEN
        SELECT COALESCE(MAX(sort_order), 0) + 1 INTO v_next_order FROM public.team_players WHERE team_id = p_team_id;
    ELSE
        v_next_order := p_sort_order;
    END IF;

    INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
    VALUES (p_team_id, p_source_name, p_is_captain, v_next_order)
    RETURNING id INTO v_id;

    RETURN v_id;
END;
$$;

-- CRUD: Remove a player from a team
CREATE OR REPLACE FUNCTION public.fn_remove_team_player(p_player_id bigint)
RETURNS boolean
LANGUAGE sql
AS $$
    DELETE FROM public.team_players WHERE id = p_player_id RETURNING true;
$$;

-- CRUD: Update a player's name and/or captain status
CREATE OR REPLACE FUNCTION public.fn_update_team_player(
    p_player_id bigint,
    p_source_name text DEFAULT NULL,
    p_is_captain boolean DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE public.team_players
    SET source_name = COALESCE(p_source_name, source_name),
        is_captain = COALESCE(p_is_captain, is_captain)
    WHERE id = p_player_id;
    RETURN FOUND;
END;
$$;

-- Integration: Build n8n Mailout Job Context
-- This function generates a JSONB object formatted for the 'send-team-captain-contact-lists' n8n workflow.
CREATE OR REPLACE FUNCTION public.fn_get_team_mailout_job(p_team_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_res jsonb;
BEGIN
    WITH team_snapshot AS (
        SELECT 
            t.id, t.doc_source, t.team_name, t.section, t.sort_order, t.season,
            (SELECT team_name FROM public.teams 
             WHERE section = t.section AND season = t.season AND sort_order > t.sort_order 
             ORDER BY sort_order ASC LIMIT 1) AS next_team_name,
            -- Pre-calculate slugs
            trim(both '-' from regexp_replace(lower(t.team_name), '[^a-z0-9]+', '-', 'g')) as own_slug,
            (SELECT trim(both '-' from regexp_replace(lower(team_name), '[^a-z0-9]+', '-', 'g')) FROM public.teams 
             WHERE section = t.section AND season = t.season AND sort_order > t.sort_order 
             ORDER BY sort_order ASC LIMIT 1) as next_slug,
            'reserves' as reserves_slug
        FROM public.teams t
        WHERE t.id = p_team_id
    ),
    captain_info AS (
        SELECT 
            m.source_name AS captain_name,
            m.self_email AS captain_email,
            m.resolved_name AS captain_resolved_name
        FROM public.vw_appsmith_team_player_matching m
        JOIN public.team_players tp ON tp.id = m.team_player_id
        WHERE tp.team_id = p_team_id AND tp.is_captain = true
        LIMIT 1
    )
    SELECT jsonb_build_object(
        'source_doc', ts.doc_source,
        'section', ts.section,
        'team_name', ts.team_name,
        'next_team_name', COALESCE(ts.next_team_name, 'Reserves'),
        'captain_name', COALESCE(ci.captain_name, 'Unknown Captain'),
        'captain_email', COALESCE(ci.captain_email, ''),
        'own_pdf', ts.doc_source || ' - ' || ts.own_slug || '.pdf',
        'next_pdf', CASE 
                      WHEN ts.next_team_name IS NOT NULL THEN ts.doc_source || ' - ' || ts.next_slug || '.pdf' 
                      ELSE ts.doc_source || ' - ' || ts.reserves_slug || '.pdf' 
                    END,
        'reserves_pdf', ts.doc_source || ' - ' || ts.reserves_slug || '.pdf',
        'can_send', CASE WHEN ci.captain_email IS NOT NULL AND ci.captain_email != '' THEN true ELSE false END,
        'season', ts.season
    ) INTO v_res
    FROM team_snapshot ts
    LEFT JOIN captain_info ci ON true;

    RETURN v_res;
END;
$$;

COMMIT;
