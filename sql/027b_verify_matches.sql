-- Expanded verification script for team matching logic
-- Testing exact matches, nicknames, multi-part names, and non-existent players.

INSERT INTO public.teams (team_name, season) VALUES ('Test Verification Team', '2026')
ON CONFLICT DO NOTHING;

WITH t AS (SELECT id FROM public.teams WHERE team_name = 'Test Verification Team' AND season = '2026')
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
SELECT t.id, 'Katherine Rogers', true, 1 FROM t
UNION ALL
SELECT t.id, 'Kat Rogers', false, 2 FROM t -- Nickname Match
UNION ALL
SELECT t.id, 'kat rogers', false, 3 FROM t -- Case Insensitive Nickname Match
UNION ALL
SELECT t.id, '  Kat Rogers  ', false, 4 FROM t -- Whitespace Nickname Match
UNION ALL
SELECT t.id, 'Jax S B', false, 5 FROM t -- Multi-part Nickname/Override Match
UNION ALL
SELECT t.id, 'Rich Sharples', false, 6 FROM t -- Exact Match
UNION ALL
SELECT t.id, 'Non Existent Player', false, 7 FROM t -- No Match
ON CONFLICT DO NOTHING;

COMMIT;
