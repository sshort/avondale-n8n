alter table public.member_signups
    add column if not exists source text;

update public.member_signups
set source = 'email_capture'
where source is null
   or btrim(source) = '';

alter table public.member_signups
    alter column source set default 'email_capture';

alter table public.member_signups
    alter column source set not null;

create index if not exists idx_member_signups_source
    on public.member_signups (source);
