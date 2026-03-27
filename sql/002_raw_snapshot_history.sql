create table if not exists public.raw_snapshot_state (
    table_name text primary key,
    current_snapshot_year integer not null,
    updated_at timestamptz not null default now()
);

insert into public.raw_snapshot_state (table_name, current_snapshot_year)
values
    ('raw_contacts', extract(year from current_date)::integer),
    ('raw_members', extract(year from current_date)::integer)
on conflict (table_name) do nothing;

create table if not exists public.raw_contacts_historical (
    like public.raw_contacts including defaults,
    snapshot_year integer not null,
    archived_at timestamptz not null default now(),
    snapshot_source text not null default 'raw_contacts'
);

create table if not exists public.raw_members_historical (
    like public.raw_members including defaults,
    snapshot_year integer not null,
    archived_at timestamptz not null default now(),
    snapshot_source text not null default 'raw_members'
);

create index if not exists idx_raw_contacts_historical_snapshot_year
    on public.raw_contacts_historical (snapshot_year);

create index if not exists idx_raw_members_historical_snapshot_year
    on public.raw_members_historical (snapshot_year);

create or replace function public.prepare_raw_contacts_import(
    p_new_snapshot_year integer default extract(year from current_date)::integer
)
returns table (
    previous_snapshot_year integer,
    archived_row_count integer,
    current_snapshot_year integer
)
language plpgsql
as $$
declare
    v_previous_snapshot_year integer;
    v_archived_row_count integer := 0;
begin
    select rss.current_snapshot_year
    into v_previous_snapshot_year
    from public.raw_snapshot_state rss
    where rss.table_name = 'raw_contacts'
    for update;

    if not found then
        insert into public.raw_snapshot_state (table_name, current_snapshot_year)
        values ('raw_contacts', p_new_snapshot_year)
        returning current_snapshot_year into v_previous_snapshot_year;
    end if;

    if exists (select 1 from public.raw_contacts) then
        insert into public.raw_contacts_historical (
            "Venue ID",
            "Unique ID",
            "First name",
            "Last name",
            gender,
            age,
            junior,
            "Date of birth",
            "Email address",
            "Phone number",
            "Work number",
            "Mobile number",
            "Emergency contact name",
            "Emergency phone number",
            "Address 1",
            "Address 2",
            "Address 3",
            town,
            county,
            country,
            postcode,
            "British Tennis Number",
            "Date joined venue",
            "Medical history",
            occupation,
            registered,
            unsubscribed,
            "Member status",
            "Last active",
            created,
            "Receipt of Emails",
            "Share Contact Detail",
            "Member's Directory",
            photography,
            snapshot_year,
            archived_at,
            snapshot_source
        )
        select
            rc."Venue ID",
            rc."Unique ID",
            rc."First name",
            rc."Last name",
            rc.gender,
            rc.age,
            rc.junior,
            rc."Date of birth",
            rc."Email address",
            rc."Phone number",
            rc."Work number",
            rc."Mobile number",
            rc."Emergency contact name",
            rc."Emergency phone number",
            rc."Address 1",
            rc."Address 2",
            rc."Address 3",
            rc.town,
            rc.county,
            rc.country,
            rc.postcode,
            rc."British Tennis Number",
            rc."Date joined venue",
            rc."Medical history",
            rc.occupation,
            rc.registered,
            rc.unsubscribed,
            rc."Member status",
            rc."Last active",
            rc.created,
            rc."Receipt of Emails",
            rc."Share Contact Detail",
            rc."Member's Directory",
            rc.photography,
            v_previous_snapshot_year,
            now(),
            'raw_contacts'
        from public.raw_contacts rc;

        get diagnostics v_archived_row_count = row_count;
    end if;

    truncate table public.raw_contacts;

    update public.raw_snapshot_state
    set current_snapshot_year = p_new_snapshot_year,
        updated_at = now()
    where table_name = 'raw_contacts';

    return query
    select
        v_previous_snapshot_year,
        v_archived_row_count,
        p_new_snapshot_year;
end;
$$;

create or replace function public.prepare_raw_members_import(
    p_new_snapshot_year integer default extract(year from current_date)::integer
)
returns table (
    previous_snapshot_year integer,
    archived_row_count integer,
    current_snapshot_year integer
)
language plpgsql
as $$
declare
    v_previous_snapshot_year integer;
    v_archived_row_count integer := 0;
begin
    select rss.current_snapshot_year
    into v_previous_snapshot_year
    from public.raw_snapshot_state rss
    where rss.table_name = 'raw_members'
    for update;

    if not found then
        insert into public.raw_snapshot_state (table_name, current_snapshot_year)
        values ('raw_members', p_new_snapshot_year)
        returning current_snapshot_year into v_previous_snapshot_year;
    end if;

    if exists (select 1 from public.raw_members)
       and p_new_snapshot_year > v_previous_snapshot_year then
        delete from public.raw_members_historical
        where snapshot_year = v_previous_snapshot_year;

        insert into public.raw_members_historical (
            "Venue ID",
            "First name",
            "Last name",
            "Gender",
            "Age",
            "Junior",
            "Date of birth",
            "Membership",
            "Payment",
            "Cost",
            "Paid",
            "Paid Credit Card",
            "Paid Direct Debit",
            "Paid Cash",
            "Paid Cheque",
            "Paid Other",
            "Gift aid",
            "Status",
            "Start Date",
            "Expiry Date",
            "Email address",
            "Phone number",
            "Work number",
            "Mobile number",
            "Emergency contact name",
            "Emergency phone number",
            "Address 1",
            "Address 2",
            "Address 3",
            "Town",
            "County",
            "Country",
            "Postcode",
            "British Tennis Number",
            "Date joined venue",
            "Medical history",
            "Venue source",
            "Contact source",
            "Occupation",
            "Tags provided",
            "Key pin number",
            "Registered",
            "Member status",
            "Receipt of Emails",
            "Share Contact Detail",
            "Member's Directory",
            "Photography",
            " Venue source",
            snapshot_year,
            archived_at,
            snapshot_source
        )
        select
            rm."Venue ID",
            rm."First name",
            rm."Last name",
            rm."Gender",
            rm."Age",
            rm."Junior",
            rm."Date of birth",
            rm."Membership",
            rm."Payment",
            rm."Cost",
            rm."Paid",
            rm."Paid Credit Card",
            rm."Paid Direct Debit",
            rm."Paid Cash",
            rm."Paid Cheque",
            rm."Paid Other",
            rm."Gift aid",
            rm."Status",
            rm."Start Date",
            rm."Expiry Date",
            rm."Email address",
            rm."Phone number",
            rm."Work number",
            rm."Mobile number",
            rm."Emergency contact name",
            rm."Emergency phone number",
            rm."Address 1",
            rm."Address 2",
            rm."Address 3",
            rm."Town",
            rm."County",
            rm."Country",
            rm."Postcode",
            rm."British Tennis Number",
            rm."Date joined venue",
            rm."Medical history",
            rm."Venue source",
            rm."Contact source",
            rm."Occupation",
            rm."Tags provided",
            rm."Key pin number",
            rm."Registered",
            rm."Member status",
            rm."Receipt of Emails",
            rm."Share Contact Detail",
            rm."Member's Directory",
            rm."Photography",
            rm." Venue source",
            v_previous_snapshot_year,
            now(),
            'raw_members'
        from public.raw_members rm;

        get diagnostics v_archived_row_count = row_count;
    end if;

    truncate table public.raw_members;

    update public.raw_snapshot_state
    set current_snapshot_year = p_new_snapshot_year,
        updated_at = now()
    where table_name = 'raw_members';

    return query
    select
        v_previous_snapshot_year,
        v_archived_row_count,
        p_new_snapshot_year;
end;
$$;

create or replace view public.vw_raw_contacts_all as
select
    rc."Venue ID",
    rc."Unique ID",
    rc."First name",
    rc."Last name",
    rc.gender,
    rc.age,
    rc.junior,
    rc."Date of birth",
    rc."Email address",
    rc."Phone number",
    rc."Work number",
    rc."Mobile number",
    rc."Emergency contact name",
    rc."Emergency phone number",
    rc."Address 1",
    rc."Address 2",
    rc."Address 3",
    rc.town,
    rc.county,
    rc.country,
    rc.postcode,
    rc."British Tennis Number",
    rc."Date joined venue",
    rc."Medical history",
    rc.occupation,
    rc.registered,
    rc.unsubscribed,
    rc."Member status",
    rc."Last active",
    rc.created,
    rc."Receipt of Emails",
    rc."Share Contact Detail",
    rc."Member's Directory",
    rc.photography,
    rss.current_snapshot_year as snapshot_year,
    true as is_current,
    rss.updated_at as snapshot_recorded_at,
    'raw_contacts_current'::text as snapshot_source
from public.raw_contacts rc
join public.raw_snapshot_state rss
  on rss.table_name = 'raw_contacts'
where coalesce(rc.is_current, true) = true
union all
select
    rch."Venue ID",
    rch."Unique ID",
    rch."First name",
    rch."Last name",
    rch.gender,
    rch.age,
    rch.junior,
    rch."Date of birth",
    rch."Email address",
    rch."Phone number",
    rch."Work number",
    rch."Mobile number",
    rch."Emergency contact name",
    rch."Emergency phone number",
    rch."Address 1",
    rch."Address 2",
    rch."Address 3",
    rch.town,
    rch.county,
    rch.country,
    rch.postcode,
    rch."British Tennis Number",
    rch."Date joined venue",
    rch."Medical history",
    rch.occupation,
    rch.registered,
    rch.unsubscribed,
    rch."Member status",
    rch."Last active",
    rch.created,
    rch."Receipt of Emails",
    rch."Share Contact Detail",
    rch."Member's Directory",
    rch.photography,
    rch.snapshot_year,
    false as is_current,
    rch.archived_at as snapshot_recorded_at,
    rch.snapshot_source
from public.raw_contacts_historical rch;

create or replace view public.vw_raw_members_all as
select
    rm."Venue ID",
    rm."First name",
    rm."Last name",
    rm."Gender",
    rm."Age",
    rm."Junior",
    rm."Date of birth",
    rm."Membership",
    rm."Payment",
    rm."Cost",
    rm."Paid",
    rm."Paid Credit Card",
    rm."Paid Direct Debit",
    rm."Paid Cash",
    rm."Paid Cheque",
    rm."Paid Other",
    rm."Gift aid",
    rm."Status",
    rm."Start Date",
    rm."Expiry Date",
    rm."Email address",
    rm."Phone number",
    rm."Work number",
    rm."Mobile number",
    rm."Emergency contact name",
    rm."Emergency phone number",
    rm."Address 1",
    rm."Address 2",
    rm."Address 3",
    rm."Town",
    rm."County",
    rm."Country",
    rm."Postcode",
    rm."British Tennis Number",
    rm."Date joined venue",
    rm."Medical history",
    rm."Venue source",
    rm."Contact source",
    rm."Occupation",
    rm."Tags provided",
    rm."Key pin number",
    rm."Registered",
    rm."Member status",
    rm."Receipt of Emails",
    rm."Share Contact Detail",
    rm."Member's Directory",
    rm."Photography",
    rm." Venue source",
    rss.current_snapshot_year as snapshot_year,
    true as is_current,
    rss.updated_at as snapshot_recorded_at,
    'raw_members_current'::text as snapshot_source
from public.raw_members rm
join public.raw_snapshot_state rss
  on rss.table_name = 'raw_members'
where coalesce(rm.is_current, true) = true
union all
select
    rmh."Venue ID",
    rmh."First name",
    rmh."Last name",
    rmh."Gender",
    rmh."Age",
    rmh."Junior",
    rmh."Date of birth",
    rmh."Membership",
    rmh."Payment",
    rmh."Cost",
    rmh."Paid",
    rmh."Paid Credit Card",
    rmh."Paid Direct Debit",
    rmh."Paid Cash",
    rmh."Paid Cheque",
    rmh."Paid Other",
    rmh."Gift aid",
    rmh."Status",
    rmh."Start Date",
    rmh."Expiry Date",
    rmh."Email address",
    rmh."Phone number",
    rmh."Work number",
    rmh."Mobile number",
    rmh."Emergency contact name",
    rmh."Emergency phone number",
    rmh."Address 1",
    rmh."Address 2",
    rmh."Address 3",
    rmh."Town",
    rmh."County",
    rmh."Country",
    rmh."Postcode",
    rmh."British Tennis Number",
    rmh."Date joined venue",
    rmh."Medical history",
    rmh."Venue source",
    rmh."Contact source",
    rmh."Occupation",
    rmh."Tags provided",
    rmh."Key pin number",
    rmh."Registered",
    rmh."Member status",
    rmh."Receipt of Emails",
    rmh."Share Contact Detail",
    rmh."Member's Directory",
    rmh."Photography",
    rmh." Venue source",
    rmh.snapshot_year,
    false as is_current,
    rmh.archived_at as snapshot_recorded_at,
    rmh.snapshot_source
from public.raw_members_historical rmh;

create or replace view public.vw_members_current_and_historical as
select *
from public.vw_raw_members_all;

create or replace view public.vw_contacts_current_and_historical as
select *
from public.vw_raw_contacts_all;

create or replace function public.prepare_raw_contacts_import(
    p_new_snapshot_year integer default extract(year from current_date)::integer
)
returns table (
    previous_snapshot_year integer,
    archived_row_count integer,
    current_snapshot_year integer
)
language plpgsql
as $function$
begin
    raise exception 'prepare_raw_contacts_import(%) is retired. Use prepare_raw_contacts_import_staging() and reconcile_raw_contacts_from_staging() instead.', p_new_snapshot_year;
end;
$function$;

create or replace function public.prepare_raw_members_import(
    p_new_snapshot_year integer default extract(year from current_date)::integer
)
returns table (
    previous_snapshot_year integer,
    archived_row_count integer,
    current_snapshot_year integer
)
language plpgsql
as $function$
begin
    raise exception 'prepare_raw_members_import(%) is retired. Use prepare_raw_members_import_staging() and reconcile_raw_members_from_staging() instead.', p_new_snapshot_year;
end;
$function$;
