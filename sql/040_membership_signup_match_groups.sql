create table if not exists public.membership_signup_match_groups (
  season varchar(16) not null,
  package_name varchar(64) not null,
  signup_match_group varchar(64) not null,
  primary key (season, package_name)
);

insert into public.membership_signup_match_groups (season, package_name, signup_match_group)
values
  ('2025', '4. Junior 2025', 'junior_family'),
  ('2025', '5. Senior Junior 2025', 'junior_family'),
  ('2026', '4. Junior 2026', 'junior_family'),
  ('2026', '8. Senior Junior 2026', 'junior_family')
on conflict (season, package_name) do update
set signup_match_group = excluded.signup_match_group;
