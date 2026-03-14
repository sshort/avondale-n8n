create table if not exists public.signup_batches (
    id bigserial primary key,
    status text not null check (status in ('Processing', 'Complete')),
    created_at timestamptz not null default now(),
    completed_at timestamptz
);

alter table public.member_signups
    add column if not exists id bigint,
    add column if not exists clubspark_status varchar(32),
    add column if not exists batch_id bigint;

create sequence if not exists public.member_signups_id_seq;

alter sequence public.member_signups_id_seq
    owned by public.member_signups.id;

alter table public.member_signups
    alter column id set default nextval('public.member_signups_id_seq');

update public.member_signups
set id = nextval('public.member_signups_id_seq')
where id is null;

select setval(
    'public.member_signups_id_seq',
    coalesce((select max(id) from public.member_signups), 1),
    true
);

update public.member_signups
set clubspark_status = status
where clubspark_status is null
  and status is not null;

update public.member_signups
set status = 'Complete'
where status not in ('New', 'Processing', 'Complete', 'Error')
   or status is null;

alter table public.member_signups
    alter column id set not null,
    alter column status set default 'New';

create unique index if not exists idx_member_signups_id
    on public.member_signups (id);

create index if not exists idx_member_signups_status
    on public.member_signups (status);

create index if not exists idx_member_signups_batch_id
    on public.member_signups (batch_id);

create index if not exists idx_signup_batches_status
    on public.signup_batches (status);

do $$
begin
    if not exists (
        select 1
        from information_schema.table_constraints
        where table_schema = 'public'
          and table_name = 'member_signups'
          and constraint_name = 'fk_member_signups_batch'
    ) then
        alter table public.member_signups
            add constraint fk_member_signups_batch
            foreign key (batch_id) references public.signup_batches (id);
    end if;
end $$;
