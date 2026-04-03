BEGIN;

-- Clear existing data
DELETE FROM public.team_players;
DELETE FROM public.teams;

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('LADIES TEAMS 2026 Summer', 'Ladies', 'A Squad', '2026', 1);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'A Squad' AND season = '2026'), 'Jane Dow', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'A Squad' AND season = '2026'), 'Amy Palmer', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'A Squad' AND season = '2026'), 'Jane Vincent', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'A Squad' AND season = '2026'), 'Leila Warwick', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'A Squad' AND season = '2026'), 'Sam Rush', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'A Squad' AND season = '2026'), 'Sian Thomas', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'A Squad' AND season = '2026'), 'Wendy Day', false, 7);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('LADIES TEAMS 2026 Summer', 'Ladies', 'B Squad', '2026', 2);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'B Squad' AND season = '2026'), 'Georgina Riches', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'B Squad' AND season = '2026'), 'Cath Pearson', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'B Squad' AND season = '2026'), 'Charlene Jacobs', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'B Squad' AND season = '2026'), 'Diane Doyle', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'B Squad' AND season = '2026'), 'Jacquie Conway', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'B Squad' AND season = '2026'), 'Joan Mc Crossan', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'B Squad' AND season = '2026'), 'Liz Long', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'B Squad' AND season = '2026'), 'Sally Charlton', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'B Squad' AND season = '2026'), 'Sue white', false, 9);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('LADIES TEAMS 2026 Summer', 'Ladies', 'C Squad', '2026', 3);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'C Squad' AND season = '2026'), 'Kate Liggett', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'C Squad' AND season = '2026'), 'Alison Jameson', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'C Squad' AND season = '2026'), 'Joanne Stanley', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'C Squad' AND season = '2026'), 'Katherine Rogers', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'C Squad' AND season = '2026'), 'Kim Field', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'C Squad' AND season = '2026'), 'Lynn McKenzie', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'C Squad' AND season = '2026'), 'Trish Harris', false, 7);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('LADIES TEAMS 2026 Summer', 'Ladies', 'D Squad', '2026', 4);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'D Squad' AND season = '2026'), 'Susie Cooke', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'D Squad' AND season = '2026'), 'Alicia Freimuth', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'D Squad' AND season = '2026'), 'Carol- Anne Harrison', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'D Squad' AND season = '2026'), 'Clare Bambridge', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'D Squad' AND season = '2026'), 'Fran Jones', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'D Squad' AND season = '2026'), 'Juliet Worthington', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'D Squad' AND season = '2026'), 'Sarah Gibbons', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'D Squad' AND season = '2026'), 'Susan Gilchrist', false, 8);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('LADIES TEAMS 2026 Summer', 'Ladies', 'E Squad', '2026', 5);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'E Squad' AND season = '2026'), 'Sue White', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'E Squad' AND season = '2026'), 'Claire Taylor', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'E Squad' AND season = '2026'), 'Helen Eyres', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'E Squad' AND season = '2026'), 'Jax S B', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'E Squad' AND season = '2026'), 'Jessica Palmer', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'E Squad' AND season = '2026'), 'Jo Baines', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'E Squad' AND season = '2026'), 'Lindsey Evans', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'E Squad' AND season = '2026'), 'Liz Gruenstern', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'E Squad' AND season = '2026'), 'Maew Tatam', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'E Squad' AND season = '2026'), 'Vicky Judge', false, 10);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('LADIES TEAMS 2026 Summer', 'Ladies', 'Reserves', '2026', 6);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'Reserves' AND season = '2026'), 'Becky Cockerill', false, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'Reserves' AND season = '2026'), 'Jane Woods', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'Reserves' AND season = '2026'), 'Jill Penton', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'Reserves' AND season = '2026'), 'Mo Clackett', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'Reserves' AND season = '2026'), 'Pauline Snell', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'Reserves' AND season = '2026'), 'Val Rowlands', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Ladies' AND team_name = 'Reserves' AND season = '2026'), 'Val Talbot', false, 7);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('MENS SQUADS 2026 Summer', 'Mens', 'A Squad', '2026', 1);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'A Squad' AND season = '2026'), 'David Pharo', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'A Squad' AND season = '2026'), 'Alistair Jones', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'A Squad' AND season = '2026'), 'Ben Martin', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'A Squad' AND season = '2026'), 'David Jones', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'A Squad' AND season = '2026'), 'Graham Friel', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'A Squad' AND season = '2026'), 'James Colpus', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'A Squad' AND season = '2026'), 'Jon Soul', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'A Squad' AND season = '2026'), 'Mark Elliott', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'A Squad' AND season = '2026'), 'Paul Kemsley', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'A Squad' AND season = '2026'), 'Peter Grant', false, 10);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'A Squad' AND season = '2026'), 'Stuart Lamb', false, 11);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('MENS SQUADS 2026 Summer', 'Mens', 'B Squad', '2026', 2);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'B Squad' AND season = '2026'), 'Tom Van Klaveren', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'B Squad' AND season = '2026'), 'Alec Mach', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'B Squad' AND season = '2026'), 'Andy Mc Elligot', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'B Squad' AND season = '2026'), 'ANDY ROXBURGH', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'B Squad' AND season = '2026'), 'Jacob Diskin', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'B Squad' AND season = '2026'), 'Michael Palmer', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'B Squad' AND season = '2026'), 'Oliver Casselton', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'B Squad' AND season = '2026'), 'Richard Longworth', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'B Squad' AND season = '2026'), 'Rob Bozier', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'B Squad' AND season = '2026'), 'Roni Asp', false, 10);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'B Squad' AND season = '2026'), 'Santu Asp', false, 11);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('MENS SQUADS 2026 Summer', 'Mens', 'C Squad', '2026', 3);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'C Squad' AND season = '2026'), 'Paul Hampshire', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'C Squad' AND season = '2026'), 'Chris Ezra', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'C Squad' AND season = '2026'), 'David Alston', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'C Squad' AND season = '2026'), 'James Carlisle', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'C Squad' AND season = '2026'), 'Jeremy Hillage', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'C Squad' AND season = '2026'), 'Jon Clackett', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'C Squad' AND season = '2026'), 'Mark Hill', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'C Squad' AND season = '2026'), 'Mike Thornley', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'C Squad' AND season = '2026'), 'Richard Vallis', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'C Squad' AND season = '2026'), 'Stuart Aberdeen', false, 10);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'C Squad' AND season = '2026'), 'Tom Blake', false, 11);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('MENS SQUADS 2026 Summer', 'Mens', 'D Squad', '2026', 4);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'D Squad' AND season = '2026'), 'Tim Read', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'D Squad' AND season = '2026'), 'Alek Katon', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'D Squad' AND season = '2026'), 'Antonias Nicolaidis', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'D Squad' AND season = '2026'), 'Chris Cole', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'D Squad' AND season = '2026'), 'Harry McIntyre', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'D Squad' AND season = '2026'), 'Jonty Maston', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'D Squad' AND season = '2026'), 'Nick Ward', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'D Squad' AND season = '2026'), 'Paul Treacy', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'D Squad' AND season = '2026'), 'Peter Smith', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'D Squad' AND season = '2026'), 'Roger Barnacle', false, 10);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'D Squad' AND season = '2026'), 'Steve Short', false, 11);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('MENS SQUADS 2026 Summer', 'Mens', 'E Squad', '2026', 5);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'E Squad' AND season = '2026'), 'Ben Hammond Duncan', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'E Squad' AND season = '2026'), 'Alessandro Barcello', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'E Squad' AND season = '2026'), 'Alexander Peacock', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'E Squad' AND season = '2026'), 'Ben Fowler', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'E Squad' AND season = '2026'), 'David Fowler', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'E Squad' AND season = '2026'), 'Derek Carder', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'E Squad' AND season = '2026'), 'Graeme Hutchison', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'E Squad' AND season = '2026'), 'Joel Villamayor', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'E Squad' AND season = '2026'), 'Matt Napper', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'E Squad' AND season = '2026'), 'Nigel Fisher', false, 10);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'E Squad' AND season = '2026'), 'Ray Ristow', false, 11);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('MENS SQUADS 2026 Summer', 'Mens', 'Reserves', '2026', 6);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'Reserves' AND season = '2026'), 'Andy Cholerton', false, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'Reserves' AND season = '2026'), 'Edward Long', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'Reserves' AND season = '2026'), 'Edward Woods', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'Reserves' AND season = '2026'), 'Harry Bywaters', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'Reserves' AND season = '2026'), 'James Cholerton', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'Reserves' AND season = '2026'), 'Paul Tippens', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'Reserves' AND season = '2026'), 'Sean Elliott', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mens' AND team_name = 'Reserves' AND season = '2026'), 'Tim presland', false, 8);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('MIXED TEAMS 2026 SUMMER', 'Mixed', 'A Squad', '2026', 1);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'A Squad' AND season = '2026'), 'Mark Elliott', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'A Squad' AND season = '2026'), 'Amy Palmer', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'A Squad' AND season = '2026'), 'Ben Martin', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'A Squad' AND season = '2026'), 'David Pharo', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'A Squad' AND season = '2026'), 'Jane Dow', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'A Squad' AND season = '2026'), 'Jane Vincent', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'A Squad' AND season = '2026'), 'Leila Warwick', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'A Squad' AND season = '2026'), 'Paul Kemsley', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'A Squad' AND season = '2026'), 'Peter Grant', false, 9);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('MIXED TEAMS 2026 SUMMER', 'Mixed', 'B Squad', '2026', 2);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'B Squad' AND season = '2026'), 'Sam Rush', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'B Squad' AND season = '2026'), 'Andy Roxburgh', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'B Squad' AND season = '2026'), 'Cath Pearson', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'B Squad' AND season = '2026'), 'Charlene Jacobs', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'B Squad' AND season = '2026'), 'Richard Longworth', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'B Squad' AND season = '2026'), 'Rob Bozier', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'B Squad' AND season = '2026'), 'Santu Asp', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'B Squad' AND season = '2026'), 'Sue White', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'B Squad' AND season = '2026'), 'Tom Van Klavern', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'B Squad' AND season = '2026'), 'Wendy Day', false, 10);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('MIXED TEAMS 2026 SUMMER', 'Mixed', 'C Squad', '2026', 3);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Fran Jones', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Alex Mach', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Alexander Peacock', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Alison Jamieson', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'David Alston', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Diane Doyle', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'James Carlisle', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Joanne Stanley', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Kim Field', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Lynne McKenzie', false, 10);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Mark Hill', false, 11);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Mike Thornley', false, 12);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Pauline Snell', false, 13);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Peter Smith', false, 14);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Stuart Aberdeen', false, 15);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'C Squad' AND season = '2026'), 'Tom Blake', false, 16);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('MIXED TEAMS 2026 SUMMER', 'Mixed', 'D Squad', '2026', 4);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Juliet Worthington', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Alex katon', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Antonis Nicolaidis', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Ben Hammond Duncan', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Carol Ann Harrison', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Claire Taylor', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Graeme Hutcheson', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Harry McIntyre', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Jax S B', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Jessica Palmer', false, 10);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Joel Villamayor', false, 11);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Jonty Maston', false, 12);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Liz Gruernstern', false, 13);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Maew Tatum', false, 14);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Nigel Fisher', false, 15);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Paul Tippens', false, 16);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Roger Barnacle', false, 17);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Steve Short', false, 18);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Susan Gilchrist', false, 19);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'D Squad' AND season = '2026'), 'Tim Read', false, 20);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('MIXED TEAMS 2026 SUMMER', 'Mixed', 'Reserves', '2026', 5);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Alistair Jones', false, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Andy McElligot', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Chris Ezra', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Cliff Church', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'David Fowler', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Derek Carder', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Edward Woods', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Georgina Riches', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Graham Friel', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'James Cholerton', false, 10);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'James Colpus', false, 11);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Jill Penton', false, 12);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Joan McCrossan', false, 13);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Jon Clackett', false, 14);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Liz Long', false, 15);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Matt Napper', false, 16);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Mo Clackett', false, 17);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Paul Hampshire', false, 18);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Paul Treacy', false, 19);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Richard Vallis', false, 20);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Sally Charlton', false, 21);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Sian Thomas', false, 22);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Stuart Lamb', false, 23);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Mixed' AND team_name = 'Reserves' AND season = '2026'), 'Val Talbot', false, 24);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('VETS  TEAMS 2026 SUMMER', 'Vets', 'A Team', '2026', 1);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'DAVID ALSTON', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'CATH PEARSON', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'CLIFF CHURCH', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'JACQUIE CONWAY', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'JANE DOW', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'JANE VINCENT', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'JEREMY HILLAGE', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'MIKE THORNLEY', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'PAUL HAMPSHIRE', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'PETER GRANT', false, 10);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'RICHARD VALLIS', false, 11);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'SALLY CHARLTON', false, 12);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'SIAN THOMAS', false, 13);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'A Team' AND season = '2026'), 'SUE WHITE', false, 14);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('VETS  TEAMS 2026 SUMMER', 'Vets', 'B Team', '2026', 2);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'B Team' AND season = '2026'), 'EDWARD WOODS', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'B Team' AND season = '2026'), 'ALEX KATON', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'B Team' AND season = '2026'), 'CHRIS EZRA', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'B Team' AND season = '2026'), 'DIANE DOYLE', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'B Team' AND season = '2026'), 'JILL PENTON', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'B Team' AND season = '2026'), 'KATHERINE ROGERS', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'B Team' AND season = '2026'), 'NICK WARD', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'B Team' AND season = '2026'), 'PAULINE SNELL', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'B Team' AND season = '2026'), 'PETE SMITH', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'B Team' AND season = '2026'), 'STUART ABERDEEN', false, 10);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'B Team' AND season = '2026'), 'VAL TALBOT', false, 11);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'B Team' AND season = '2026'), 'VERNA DUFON', false, 12);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('VETS  TEAMS 2026 SUMMER', 'Vets', 'C Team', '2026', 3);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'C Team' AND season = '2026'), 'SUSAN GILCHRIST', true, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'C Team' AND season = '2026'), 'CAROLE -ANN HARRISON', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'C Team' AND season = '2026'), 'CLAIRE TAYLOR', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'C Team' AND season = '2026'), 'DAVID HENSHAW', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'C Team' AND season = '2026'), 'DAVID WHITE', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'C Team' AND season = '2026'), 'JAX S BROWN', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'C Team' AND season = '2026'), 'JESSICA PALMER', false, 7);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'C Team' AND season = '2026'), 'JONTY MASTON', false, 8);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'C Team' AND season = '2026'), 'PAUL TREACY', false, 9);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'C Team' AND season = '2026'), 'ROGER BARNACLE', false, 10);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'C Team' AND season = '2026'), 'TIM READ', false, 11);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'C Team' AND season = '2026'), 'TRISH HARRIS', false, 12);

INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)
  VALUES ('VETS  TEAMS 2026 SUMMER', 'Vets', 'Reserves', '2026', 4);

INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'Reserves' AND season = '2026'), 'DEREK CARDER', false, 1);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'Reserves' AND season = '2026'), 'GEORGINA RICHES', false, 2);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'Reserves' AND season = '2026'), 'JON CLACKETT', false, 3);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'Reserves' AND season = '2026'), 'MAEW TATAM', false, 4);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'Reserves' AND season = '2026'), 'MO CLACKETT', false, 5);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'Reserves' AND season = '2026'), 'RAY RISTOW', false, 6);
INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)
  VALUES ((SELECT id FROM public.teams WHERE section = 'Vets' AND team_name = 'Reserves' AND season = '2026'), 'TIM PRESLAND', false, 7);

COMMIT;