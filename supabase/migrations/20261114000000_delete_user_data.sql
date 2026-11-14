-- Deletes every row owned by a user across all public tables that have a
-- user_id column. Called only by the delete-account Edge Function (service role).
create or replace function public.delete_user_data(uid uuid)
returns void language plpgsql security definer set search_path = public as $$
declare r record;
begin
  for r in
    select c.table_name from information_schema.columns c
    join information_schema.tables t on t.table_schema = c.table_schema and t.table_name = c.table_name
    where c.table_schema = 'public' and c.column_name = 'user_id' and t.table_type = 'BASE TABLE'
  loop
    execute format('delete from public.%I where user_id = $1', r.table_name) using uid;
  end loop;
end $$;
revoke all on function public.delete_user_data(uuid) from public, anon, authenticated;
grant execute on function public.delete_user_data(uuid) to service_role;
