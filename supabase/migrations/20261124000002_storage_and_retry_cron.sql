-- Gene - Nov, 24, 2026: Configure private Supabase Storage archive bucket (`eis-exports`)
-- for 10-year BIR statutory retention (.DAT, .CSV, Form 2307) and optional pg_cron 3-day SLA retry worker.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'eis-exports',
  'eis-exports',
  false,
  52428800,
  array['text/plain', 'text/csv', 'text/html', 'application/json', 'application/pdf']
)
on conflict (id) do nothing;

-- Object path convention: <workspace_id>/<taxpayer_id>/<filename>
-- Storage upsert requires SELECT + INSERT + UPDATE policies.
drop policy if exists eis_exports_member_select on storage.objects;
create policy eis_exports_member_select
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'eis-exports'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and (select private.has_workspace_role(((storage.foldername(name))[1])::uuid, null))
  );

drop policy if exists eis_exports_authorized_insert on storage.objects;
create policy eis_exports_authorized_insert
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'eis-exports'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and (select private.has_workspace_role(
      ((storage.foldername(name))[1])::uuid,
      array['admin', 'accountant', 'auditor']
    ))
  );

drop policy if exists eis_exports_authorized_update on storage.objects;
create policy eis_exports_authorized_update
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'eis-exports'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and (select private.has_workspace_role(
      ((storage.foldername(name))[1])::uuid,
      array['admin', 'accountant', 'auditor']
    ))
  )
  with check (
    bucket_id = 'eis-exports'
    and (storage.foldername(name))[1] ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
    and (select private.has_workspace_role(
      ((storage.foldername(name))[1])::uuid,
      array['admin', 'accountant', 'auditor']
    ))
  );

-- Optional automated 3-day SLA retry worker via pg_cron + pg_net + Vault secrets.
-- In Supabase Cloud or Self-Hosted with pg_cron/pg_net enabled, add Vault secrets named
-- `supabase_url` and `eis_cron_secret`, then re-run or schedule the job safely.
do $$
declare
  v_url text;
  v_cron_secret text;
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron')
     and exists (select 1 from pg_extension where extname = 'pg_net')
     and exists (select 1 from pg_namespace where nspname = 'vault') then
    execute $q$select decrypted_secret from vault.decrypted_secrets where name = 'supabase_url' limit 1$q$ into v_url;
    execute $q$select decrypted_secret from vault.decrypted_secrets where name = 'eis_cron_secret' limit 1$q$ into v_cron_secret;

    if v_url is not null and v_cron_secret is not null then
      if exists (select 1 from cron.job where jobname = 'eis-3day-retry-worker') then
        perform cron.unschedule('eis-3day-retry-worker');
      end if;

      perform cron.schedule(
        'eis-3day-retry-worker',
        '*/5 * * * *',
        format(
          $cmd$
          select net.http_post(
            url := %L,
            headers := jsonb_build_object(
              'Content-Type', 'application/json',
              'Authorization', %L
            ),
            body := '{"source":"pg_cron"}'::jsonb
          );
          $cmd$,
          rtrim(v_url, '/') || '/functions/v1/eis-retry-worker',
          'Bearer ' || v_cron_secret
        )
      );
    end if;
  end if;
end;
$$;
