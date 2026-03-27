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
