BEGIN;

INSERT INTO public.teams (team_name, season) VALUES ('Test Mens 1st', '2026');

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
SELECT 
    id, 'Katherine Rogers', true, 1 FROM public.teams WHERE team_name = 'Test Mens 1st'
UNION ALL
SELECT 
    id, 'Kat Rogers', false, 2 FROM public.teams WHERE team_name = 'Test Mens 1st'
UNION ALL
SELECT 
    id, 'Rich Sharples', false, 3 FROM public.teams WHERE team_name = 'Test Mens 1st'
UNION ALL
SELECT 
    id, 'Lucy Clements', false, 4 FROM public.teams WHERE team_name = 'Test Mens 1st'
UNION ALL
SELECT 
    id, 'Non Existent Player', false, 5 FROM public.teams WHERE team_name = 'Test Mens 1st';

COMMIT;
