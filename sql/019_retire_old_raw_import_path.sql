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
