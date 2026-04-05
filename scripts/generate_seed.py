#!/usr/bin/env python3
import csv, json, os, glob

base = '/mnt/c/dev/avondale-n8n/Teams/generated'

with open(os.path.join(base, 'team-captain-email-jobs.json')) as f:
    jobs = json.load(f)['jobs']

job_lookup = {}
for j in jobs:
    key = (j['section'], j['team_name'])
    job_lookup[key] = j

section_dirs = {
    'LADIES TEAMS 2026 Summer - CSV': 'Ladies',
    'MENS SQUADS 2026 Summer - CSV': 'Mens',
    'MIXED TEAMS 2026 SUMMER - CSV': 'Mixed',
    'VETS  TEAMS 2026 SUMMER - CSV': 'Vets',
}

team_name_map = {
    'a-squad': 'A Squad', 'b-squad': 'B Squad', 'c-squad': 'C Squad',
    'd-squad': 'D Squad', 'e-squad': 'E Squad',
    'a-team': 'A Team', 'b-team': 'B Team', 'c-team': 'C Team',
    'reserves': 'Reserves',
}

def sql_lit(v):
    if v is None:
        return 'NULL'
    return "'" + str(v).replace("'", "''") + "'"

lines = ['BEGIN;', '', '-- Clear existing data', 'DELETE FROM public.team_players;', 'DELETE FROM public.teams;', '']

for dir_name, section in sorted(section_dirs.items()):
    csv_dir = os.path.join(base, dir_name)
    sort_order = 0
    for csv_file in sorted(glob.glob(os.path.join(csv_dir, '*.csv'))):
        fname = os.path.splitext(os.path.basename(csv_file))[0]
        team_name = team_name_map.get(fname, fname.replace('-', ' ').title())
        sort_order += 1

        job = job_lookup.get((section, team_name), {})
        doc_source = job.get('source_doc', dir_name.replace(' - CSV', ''))

        lines.append(f"INSERT INTO public.teams (doc_source, section, team_name, season, sort_order)")
        lines.append(f"  VALUES ({sql_lit(doc_source)}, {sql_lit(section)}, {sql_lit(team_name)}, '2026', {sort_order});")
        lines.append('')

        with open(csv_file) as f:
            reader = csv.DictReader(f)
            player_order = 0
            for row in reader:
                player_order += 1
                name = (row.get('Name') or '').strip()
                is_captain = (row.get('Captain') or '').strip() == 'C'
                if name:
                    lines.append(f"INSERT INTO public.team_players (team_id, source_name, is_captain, sort_order)")
                    lines.append(f"  VALUES ((SELECT id FROM public.teams WHERE section = {sql_lit(section)} AND team_name = {sql_lit(team_name)} AND season = '2026'), {sql_lit(name)}, {str(is_captain).lower()}, {player_order});")
        lines.append('')

lines.append('COMMIT;')

out_path = '/mnt/c/dev/avondale-n8n/sql/028b_seed_teams.sql'
with open(out_path, 'w') as f:
    f.write('\n'.join(lines))

team_count = sum(1 for l in lines if l.startswith('INSERT INTO public.teams'))
player_count = sum(1 for l in lines if l.startswith('INSERT INTO public.team_players'))
print(f'Generated {out_path}: {team_count} teams, {player_count} players')
