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
        insert into public.raw_contacts_historical
        select
            public.raw_contacts.*,
            v_previous_snapshot_year,
            now(),
            'raw_contacts'
        from public.raw_contacts;

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
