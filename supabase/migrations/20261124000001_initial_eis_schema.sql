-- Gene - Nov, 24, 2026: Initial Supabase PostgreSQL schema for Philippine BIR EIS v2.01 & CAS Compliance Platform.
-- Enforces tenant isolation via RLS, non-exposed private key vault, exact numeric(18,2) money math,
-- gapless sequence reservation, and RMC 5-2021 / RMO 9-2021 immutable ledger & Annex B hash-chain triggers.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- 1. Non-exposed private schema (never included in PostgREST [api].schemas)
-- ---------------------------------------------------------------------------
create schema if not exists private;
revoke all on schema private from PUBLIC, anon, authenticated;
grant usage on schema private to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 2. Workspaces, RBAC Memberships, and BIR Gateway Configuration
-- ---------------------------------------------------------------------------
create table if not exists public.workspaces (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.workspace_members (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  email text not null,
  role text not null check (role in ('admin', 'accountant', 'cashier', 'auditor', 'security_officer')),
  created_at timestamptz not null default now(),
  unique (workspace_id, user_id)
);

create index if not exists workspace_members_workspace_user_idx
  on public.workspace_members (workspace_id, user_id);
create index if not exists workspace_members_user_id_idx
  on public.workspace_members (user_id);

create table if not exists public.gateway_configs (
  workspace_id uuid primary key references public.workspaces (id) on delete cascade,
  mode text not null default 'MOCK_BIR_SIMULATOR'
    check (mode in ('MOCK_BIR_SIMULATOR', 'BIR_CERT_SANDBOX', 'BIR_PRODUCTION')),
  simulate_outage boolean not null default false,
  cert_endpoint text not null default 'https://eis-cert.bir.gov.ph/api/v2.01/invoices',
  prod_endpoint text not null default 'https://eis.bir.gov.ph/api/v2.01/invoices',
  updated_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 3. Taxpayer Profiles, Branches & Encrypted Private Key Vault
-- ---------------------------------------------------------------------------
create table if not exists public.taxpayers (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  tin text not null check (tin ~ '^\d{9}$'),
  tax_type text not null default 'VAT' check (tax_type in ('VAT', 'NON_VAT')),
  registered_name text not null,
  business_name text not null,
  email text not null,
  eis_cert_id text not null,
  ptt_number text not null,
  key_id text not null,
  public_key_json text not null,
  last_eis_sequence bigint not null default 0,
  created_at timestamptz not null default now(),
  unique (workspace_id, tin)
);

create index if not exists taxpayers_workspace_id_idx
  on public.taxpayers (workspace_id);

create table if not exists public.taxpayer_branches (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  taxpayer_id uuid not null references public.taxpayers (id) on delete cascade,
  branch_cd text not null check (branch_cd ~ '^\d{4}$'),
  branch_name text not null,
  address jsonb not null default '{}'::jsonb,
  last_sequence bigint not null default 0,
  invoice_prefix text not null,
  created_at timestamptz not null default now(),
  unique (taxpayer_id, branch_cd)
);

create index if not exists taxpayer_branches_workspace_id_idx
  on public.taxpayer_branches (workspace_id);
create index if not exists taxpayer_branches_taxpayer_id_idx
  on public.taxpayer_branches (taxpayer_id);

-- Private key vault: isolated in `private` schema, never exposed to PostgREST or clients.
create table if not exists private.taxpayer_secrets (
  taxpayer_id uuid primary key references public.taxpayers (id) on delete cascade,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  key_id text not null,
  encrypted_private_key_jwk text not null,
  encrypted_aes_key_hex text not null,
  key_version integer not null default 1,
  rotated_at timestamptz not null default now()
);

create index if not exists taxpayer_secrets_workspace_id_idx
  on private.taxpayer_secrets (workspace_id);

revoke all on table private.taxpayer_secrets from PUBLIC, anon, authenticated;
grant select, insert, update, delete on table private.taxpayer_secrets to service_role;

-- ---------------------------------------------------------------------------
-- 4. BIR EIS v2.01 Invoices, CAS 6 Mandatory Books & Annex B Audit Trail
-- ---------------------------------------------------------------------------
create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  taxpayer_id uuid not null references public.taxpayers (id) on delete restrict,
  branch_cd text not null check (branch_cd ~ '^\d{4}$'),
  eis_unique_id text not null unique,
  comp_invoice_id text not null,
  issue_dtm text not null,
  doc_type text not null,
  trans_class text not null,
  system_type text not null,
  source_system text not null,
  external_ref_id text,
  direction text not null check (direction in ('SALES', 'PURCHASE')),
  is_paid boolean not null default false,
  ref_eis_unique_id text,
  gross_sales_amt numeric(18,2) not null default 0,
  total_discount_amt numeric(18,2) not null default 0,
  sc_pwd_discount_amt numeric(18,2) not null default 0,
  net_sales numeric(18,2) not null default 0,
  vatable_sales numeric(18,2) not null default 0,
  vat_exempt_sales numeric(18,2) not null default 0,
  zero_rated_sales numeric(18,2) not null default 0,
  vat_amt numeric(18,2) not null default 0,
  withholding_tax_amt numeric(18,2) not null default 0,
  other_charges_amt numeric(18,2) not null default 0,
  total_amount_due numeric(18,2) not null default 0,
  payload jsonb not null,
  jws_token text not null,
  aes_envelope jsonb not null,
  status text not null check (status in ('DRAFT', 'QUEUED_RETRY', 'TRANSMITTED', 'REJECTED')),
  retry_count integer not null default 0,
  next_retry_at timestamptz,
  three_day_deadline_at timestamptz not null,
  last_receipt jsonb,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists invoices_workspace_created_idx
  on public.invoices (workspace_id, created_at desc);
create index if not exists invoices_taxpayer_created_idx
  on public.invoices (taxpayer_id, created_at desc);
create index if not exists invoices_reporting_idx
  on public.invoices (workspace_id, taxpayer_id, direction, issue_dtm);
create index if not exists invoices_queued_retry_idx
  on public.invoices (next_retry_at)
  where status = 'QUEUED_RETRY';

create table if not exists public.cas_journal_entries (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  taxpayer_id uuid not null references public.taxpayers (id) on delete restrict,
  invoice_id uuid references public.invoices (id) on delete restrict,
  branch_cd text not null,
  book_type text not null check (book_type in ('GJ', 'GL', 'SJ', 'PJ', 'CRJ', 'CDJ')),
  entry_date date not null,
  reference_no text not null,
  eis_unique_id text not null,
  counterparty_name text not null,
  counterparty_tin text,
  particulars text not null,
  total_debit numeric(18,2) not null,
  total_credit numeric(18,2) not null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  constraint cas_entry_balanced check (total_debit = total_credit)
);

create index if not exists cas_journal_entries_workspace_created_idx
  on public.cas_journal_entries (workspace_id, created_at desc);
create index if not exists cas_journal_entries_taxpayer_book_idx
  on public.cas_journal_entries (taxpayer_id, book_type, entry_date desc);
create index if not exists cas_journal_entries_invoice_idx
  on public.cas_journal_entries (invoice_id);

create table if not exists public.cas_journal_lines (
  id bigint generated always as identity primary key,
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  journal_entry_id uuid not null references public.cas_journal_entries (id) on delete restrict,
  line_no integer not null,
  account_code text not null,
  account_name text not null,
  debit numeric(18,2) not null default 0,
  credit numeric(18,2) not null default 0,
  constraint cas_line_one_sided check ((debit > 0 and credit = 0) or (credit > 0 and debit = 0))
);

create index if not exists cas_journal_lines_entry_id_idx
  on public.cas_journal_lines (journal_entry_id, line_no);
create index if not exists cas_journal_lines_workspace_id_idx
  on public.cas_journal_lines (workspace_id);

create table if not exists public.audit_trail_entries (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  seq bigint not null,
  audit_code text not null,
  recorded_at text not null,
  actor_id uuid references auth.users (id) on delete set null,
  actor text not null,
  action text not null,
  taxpayer_tin text not null,
  entity_type text not null,
  entity_id text not null,
  details text not null,
  prev_hash text not null,
  entry_hash text not null,
  unique (workspace_id, seq)
);

create index if not exists audit_trail_entries_workspace_seq_idx
  on public.audit_trail_entries (workspace_id, seq desc);

create table if not exists public.erp_webhook_keys (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces (id) on delete cascade,
  connector text not null check (connector in ('xero', 'quickbooks', 'odoo', 'csv', 'generic_pos')),
  label text not null,
  key_prefix text not null,
  key_hash text not null unique,
  is_active boolean not null default true,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists erp_webhook_keys_workspace_id_idx
  on public.erp_webhook_keys (workspace_id);

-- ---------------------------------------------------------------------------
-- 5. BIR CAS Immutability Trigger (RMO 9-2021: append-only books & audit log)
-- ---------------------------------------------------------------------------
create or replace function private.prevent_immutable_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'BIR CAS Compliance Violation: table %.% is append-only; use Credit/Debit Memo adjustments instead of %.',
    tg_table_schema, tg_table_name, tg_op;
end;
$$;

drop trigger if exists cas_journal_entries_immutable on public.cas_journal_entries;
create trigger cas_journal_entries_immutable
  before update or delete on public.cas_journal_entries
  for each row execute function private.prevent_immutable_mutation();

drop trigger if exists cas_journal_lines_immutable on public.cas_journal_lines;
create trigger cas_journal_lines_immutable
  before update or delete on public.cas_journal_lines
  for each row execute function private.prevent_immutable_mutation();

drop trigger if exists audit_trail_entries_immutable on public.audit_trail_entries;
create trigger audit_trail_entries_immutable
  before update or delete on public.audit_trail_entries
  for each row execute function private.prevent_immutable_mutation();

-- ---------------------------------------------------------------------------
-- 6. Security & Atomic Operational Functions
-- ---------------------------------------------------------------------------
create or replace function private.has_workspace_role(
  p_workspace_id uuid,
  p_roles text[] default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.workspace_members m
      where m.workspace_id = p_workspace_id
        and m.user_id = (select auth.uid())
        and (p_roles is null or m.role = any (p_roles))
    );
$$;

revoke execute on function private.has_workspace_role(uuid, text[]) from PUBLIC, anon;
grant execute on function private.has_workspace_role(uuid, text[]) to authenticated, service_role;

create or replace function private.reserve_invoice_sequences(
  p_taxpayer_id uuid,
  p_branch_cd text default '0000'
)
returns table (
  workspace_id uuid,
  taxpayer_id uuid,
  tin text,
  tax_type text,
  registered_name text,
  business_name text,
  email text,
  eis_cert_id text,
  ptt_number text,
  key_id text,
  public_key_json text,
  new_eis_sequence bigint,
  branch_cd text,
  branch_name text,
  branch_address jsonb,
  invoice_prefix text,
  new_branch_sequence bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_tp public.taxpayers%rowtype;
  v_br public.taxpayer_branches%rowtype;
  v_norm_branch text;
  v_next_eis bigint;
  v_next_branch bigint;
begin
  select * into v_tp
  from public.taxpayers t
  where t.id = p_taxpayer_id
  for update;

  if not found then
    raise exception 'Taxpayer % not found.', p_taxpayer_id;
  end if;

  v_norm_branch := lpad(right(regexp_replace(coalesce(p_branch_cd, '0000'), '\D', '', 'g'), 4), 4, '0');

  select * into v_br
  from public.taxpayer_branches b
  where b.taxpayer_id = p_taxpayer_id
    and b.branch_cd = v_norm_branch
  for update;

  if not found then
    select * into v_br
    from public.taxpayer_branches b
    where b.taxpayer_id = p_taxpayer_id
    order by b.branch_cd asc
    limit 1
    for update;
  end if;

  if not found then
    raise exception 'No branch found for taxpayer %.', p_taxpayer_id;
  end if;

  v_next_eis := v_tp.last_eis_sequence + 1;
  v_next_branch := v_br.last_sequence + 1;

  update public.taxpayers
  set last_eis_sequence = v_next_eis
  where id = v_tp.id;

  update public.taxpayer_branches
  set last_sequence = v_next_branch
  where id = v_br.id;

  return query
  select
    v_tp.workspace_id,
    v_tp.id,
    v_tp.tin,
    v_tp.tax_type,
    v_tp.registered_name,
    v_tp.business_name,
    v_tp.email,
    v_tp.eis_cert_id,
    v_tp.ptt_number,
    v_tp.key_id,
    v_tp.public_key_json,
    v_next_eis,
    v_br.branch_cd,
    v_br.branch_name,
    v_br.address,
    v_br.invoice_prefix,
    v_next_branch;
end;
$$;

revoke execute on function private.reserve_invoice_sequences(uuid, text) from PUBLIC, anon, authenticated;
grant execute on function private.reserve_invoice_sequences(uuid, text) to service_role;

create or replace function private.compute_audit_entry_hash(
  p_seq bigint,
  p_audit_code text,
  p_recorded_at text,
  p_actor text,
  p_action text,
  p_taxpayer_tin text,
  p_entity_type text,
  p_entity_id text,
  p_details text,
  p_prev_hash text
)
returns text
language sql
immutable
set search_path = ''
as $$
  select encode(
    extensions.digest(
      convert_to(
        json_build_array(
          p_seq,
          p_audit_code,
          p_recorded_at,
          p_actor,
          p_action,
          p_taxpayer_tin,
          p_entity_type,
          p_entity_id,
          p_details,
          p_prev_hash
        )::text,
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );
$$;

revoke execute on function private.compute_audit_entry_hash(bigint, text, text, text, text, text, text, text, text, text) from PUBLIC, anon;
grant execute on function private.compute_audit_entry_hash(bigint, text, text, text, text, text, text, text, text, text) to authenticated, service_role;

create or replace function private.append_audit_entry(
  p_workspace_id uuid,
  p_actor_id uuid,
  p_actor text,
  p_action text,
  p_taxpayer_tin text,
  p_entity_type text,
  p_entity_id text,
  p_details text
)
returns public.audit_trail_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_last_seq bigint;
  v_prev_hash text;
  v_seq bigint;
  v_audit_code text;
  v_recorded_at text;
  v_entry_hash text;
  v_inserted public.audit_trail_entries%rowtype;
begin
  perform pg_advisory_xact_lock(hashtext('eis_audit:' || p_workspace_id::text));

  select e.seq, e.entry_hash
    into v_last_seq, v_prev_hash
  from public.audit_trail_entries e
  where e.workspace_id = p_workspace_id
  order by e.seq desc
  limit 1;

  v_seq := coalesce(v_last_seq, 0) + 1;
  v_prev_hash := coalesce(v_prev_hash, 'GENESIS-BIR-ANNEX-B');
  v_audit_code := 'AUD-' || lpad(v_seq::text, 6, '0');
  v_recorded_at := to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');

  v_entry_hash := private.compute_audit_entry_hash(
    v_seq,
    v_audit_code,
    v_recorded_at,
    coalesce(p_actor, 'system'),
    p_action,
    p_taxpayer_tin,
    p_entity_type,
    p_entity_id,
    p_details,
    v_prev_hash
  );

  insert into public.audit_trail_entries (
    workspace_id,
    seq,
    audit_code,
    recorded_at,
    actor_id,
    actor,
    action,
    taxpayer_tin,
    entity_type,
    entity_id,
    details,
    prev_hash,
    entry_hash
  ) values (
    p_workspace_id,
    v_seq,
    v_audit_code,
    v_recorded_at,
    p_actor_id,
    coalesce(p_actor, 'system'),
    p_action,
    p_taxpayer_tin,
    p_entity_type,
    p_entity_id,
    p_details,
    v_prev_hash,
    v_entry_hash
  )
  returning * into v_inserted;

  return v_inserted;
end;
$$;

revoke execute on function private.append_audit_entry(uuid, uuid, text, text, text, text, text, text) from PUBLIC, anon, authenticated;
grant execute on function private.append_audit_entry(uuid, uuid, text, text, text, text, text, text) to service_role;

create or replace function private.upsert_taxpayer_secret(
  p_taxpayer_id uuid,
  p_workspace_id uuid,
  p_key_id text,
  p_encrypted_private_key_jwk text,
  p_encrypted_aes_key_hex text,
  p_increment_version boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into private.taxpayer_secrets (
    taxpayer_id,
    workspace_id,
    key_id,
    encrypted_private_key_jwk,
    encrypted_aes_key_hex,
    key_version,
    rotated_at
  ) values (
    p_taxpayer_id,
    p_workspace_id,
    p_key_id,
    p_encrypted_private_key_jwk,
    p_encrypted_aes_key_hex,
    1,
    now()
  )
  on conflict (taxpayer_id) do update
    set key_id = excluded.key_id,
        encrypted_private_key_jwk = excluded.encrypted_private_key_jwk,
        encrypted_aes_key_hex = excluded.encrypted_aes_key_hex,
        key_version = case
          when p_increment_version then private.taxpayer_secrets.key_version + 1
          else private.taxpayer_secrets.key_version
        end,
        rotated_at = now();
end;
$$;

revoke execute on function private.upsert_taxpayer_secret(uuid, uuid, text, text, text, boolean) from PUBLIC, anon, authenticated;
grant execute on function private.upsert_taxpayer_secret(uuid, uuid, text, text, text, boolean) to service_role;

create or replace function private.get_taxpayer_secret(p_taxpayer_id uuid)
returns table (
  taxpayer_id uuid,
  workspace_id uuid,
  key_id text,
  encrypted_private_key_jwk text,
  encrypted_aes_key_hex text,
  key_version integer
)
language sql
security definer
set search_path = ''
as $$
  select
    s.taxpayer_id,
    s.workspace_id,
    s.key_id,
    s.encrypted_private_key_jwk,
    s.encrypted_aes_key_hex,
    s.key_version
  from private.taxpayer_secrets s
  where s.taxpayer_id = p_taxpayer_id;
$$;

revoke execute on function private.get_taxpayer_secret(uuid) from PUBLIC, anon, authenticated;
grant execute on function private.get_taxpayer_secret(uuid) to service_role;

-- Public wrappers for service_role RPC invocation via PostgREST (/rest/v1/rpc/*)
-- Kept SECURITY INVOKER in `public` so no SECURITY DEFINER functions exist in `public`,
-- and strictly restricted to `service_role`.
create or replace function public.reserve_invoice_sequences(
  p_taxpayer_id uuid,
  p_branch_cd text default '0000'
)
returns table (
  workspace_id uuid,
  taxpayer_id uuid,
  tin text,
  tax_type text,
  registered_name text,
  business_name text,
  email text,
  eis_cert_id text,
  ptt_number text,
  key_id text,
  public_key_json text,
  new_eis_sequence bigint,
  branch_cd text,
  branch_name text,
  branch_address jsonb,
  invoice_prefix text,
  new_branch_sequence bigint
)
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_user not in ('service_role', 'postgres', 'supabase_admin') then
    raise exception 'Forbidden: service_role required.';
  end if;
  return query select * from private.reserve_invoice_sequences(p_taxpayer_id, p_branch_cd);
end;
$$;

revoke execute on function public.reserve_invoice_sequences(uuid, text) from PUBLIC, anon, authenticated;
grant execute on function public.reserve_invoice_sequences(uuid, text) to service_role;

create or replace function public.append_audit_entry(
  p_workspace_id uuid,
  p_actor_id uuid,
  p_actor text,
  p_action text,
  p_taxpayer_tin text,
  p_entity_type text,
  p_entity_id text,
  p_details text
)
returns public.audit_trail_entries
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_row public.audit_trail_entries%rowtype;
begin
  if current_user not in ('service_role', 'postgres', 'supabase_admin') then
    raise exception 'Forbidden: service_role required.';
  end if;
  select * into v_row
  from private.append_audit_entry(
    p_workspace_id,
    p_actor_id,
    p_actor,
    p_action,
    p_taxpayer_tin,
    p_entity_type,
    p_entity_id,
    p_details
  );
  return v_row;
end;
$$;

revoke execute on function public.append_audit_entry(uuid, uuid, text, text, text, text, text, text) from PUBLIC, anon, authenticated;
grant execute on function public.append_audit_entry(uuid, uuid, text, text, text, text, text, text) to service_role;

create or replace function public.upsert_taxpayer_secret(
  p_taxpayer_id uuid,
  p_workspace_id uuid,
  p_key_id text,
  p_encrypted_private_key_jwk text,
  p_encrypted_aes_key_hex text,
  p_increment_version boolean default false
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_user not in ('service_role', 'postgres', 'supabase_admin') then
    raise exception 'Forbidden: service_role required.';
  end if;
  perform private.upsert_taxpayer_secret(
    p_taxpayer_id,
    p_workspace_id,
    p_key_id,
    p_encrypted_private_key_jwk,
    p_encrypted_aes_key_hex,
    p_increment_version
  );
end;
$$;

revoke execute on function public.upsert_taxpayer_secret(uuid, uuid, text, text, text, boolean) from PUBLIC, anon, authenticated;
grant execute on function public.upsert_taxpayer_secret(uuid, uuid, text, text, text, boolean) to service_role;

create or replace function public.get_taxpayer_secret(p_taxpayer_id uuid)
returns table (
  taxpayer_id uuid,
  workspace_id uuid,
  key_id text,
  encrypted_private_key_jwk text,
  encrypted_aes_key_hex text,
  key_version integer
)
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if current_user not in ('service_role', 'postgres', 'supabase_admin') then
    raise exception 'Forbidden: service_role required.';
  end if;
  return query select * from private.get_taxpayer_secret(p_taxpayer_id);
end;
$$;

revoke execute on function public.get_taxpayer_secret(uuid) from PUBLIC, anon, authenticated;
grant execute on function public.get_taxpayer_secret(uuid) to service_role;

create or replace function public.verify_workspace_audit_trail(p_workspace_id uuid)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_row record;
  v_expected_prev text := 'GENESIS-BIR-ANNEX-B';
  v_recomputed text;
  v_total bigint := 0;
begin
  if (select auth.uid()) is not null
     and not (select private.has_workspace_role(p_workspace_id, null)) then
    raise exception 'Unauthorized workspace audit access.';
  end if;

  for v_row in
    select
      e.seq,
      e.audit_code,
      e.recorded_at,
      e.actor,
      e.action,
      e.taxpayer_tin,
      e.entity_type,
      e.entity_id,
      e.details,
      e.prev_hash,
      e.entry_hash
    from public.audit_trail_entries e
    where e.workspace_id = p_workspace_id
    order by e.seq asc
  loop
    v_total := v_total + 1;
    if v_row.prev_hash <> v_expected_prev then
      return jsonb_build_object(
        'valid', false,
        'totalEntries', v_total,
        'brokenAtSeq', v_row.seq
      );
    end if;

    v_recomputed := private.compute_audit_entry_hash(
      v_row.seq,
      v_row.audit_code,
      v_row.recorded_at,
      v_row.actor,
      v_row.action,
      v_row.taxpayer_tin,
      v_row.entity_type,
      v_row.entity_id,
      v_row.details,
      v_row.prev_hash
    );

    if v_recomputed <> v_row.entry_hash then
      return jsonb_build_object(
        'valid', false,
        'totalEntries', v_total,
        'brokenAtSeq', v_row.seq
      );
    end if;

    v_expected_prev := v_row.entry_hash;
  end loop;

  return jsonb_build_object(
    'valid', true,
    'totalEntries', v_total,
    'brokenAtSeq', null
  );
end;
$$;

revoke execute on function public.verify_workspace_audit_trail(uuid) from PUBLIC, anon;
grant execute on function public.verify_workspace_audit_trail(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 7. Row-Level Security (RLS) on every exposed & private table
-- ---------------------------------------------------------------------------
alter table public.workspaces enable row level security;
alter table public.workspace_members enable row level security;
alter table public.gateway_configs enable row level security;
alter table public.taxpayers enable row level security;
alter table public.taxpayer_branches enable row level security;
alter table private.taxpayer_secrets enable row level security;
alter table public.invoices enable row level security;
alter table public.cas_journal_entries enable row level security;
alter table public.cas_journal_lines enable row level security;
alter table public.audit_trail_entries enable row level security;
alter table public.erp_webhook_keys enable row level security;

drop policy if exists workspaces_member_select on public.workspaces;
create policy workspaces_member_select
  on public.workspaces for select
  to authenticated
  using ((select private.has_workspace_role(id, null)));

drop policy if exists workspace_members_member_select on public.workspace_members;
create policy workspace_members_member_select
  on public.workspace_members for select
  to authenticated
  using ((select private.has_workspace_role(workspace_id, null)));

drop policy if exists workspace_members_admin_insert on public.workspace_members;
create policy workspace_members_admin_insert
  on public.workspace_members for insert
  to authenticated
  with check ((select private.has_workspace_role(workspace_id, array['admin'])));

drop policy if exists workspace_members_admin_update on public.workspace_members;
create policy workspace_members_admin_update
  on public.workspace_members for update
  to authenticated
  using ((select private.has_workspace_role(workspace_id, array['admin'])))
  with check ((select private.has_workspace_role(workspace_id, array['admin'])));

drop policy if exists workspace_members_admin_delete on public.workspace_members;
create policy workspace_members_admin_delete
  on public.workspace_members for delete
  to authenticated
  using ((select private.has_workspace_role(workspace_id, array['admin'])));

drop policy if exists gateway_configs_member_select on public.gateway_configs;
create policy gateway_configs_member_select
  on public.gateway_configs for select
  to authenticated
  using ((select private.has_workspace_role(workspace_id, null)));

drop policy if exists taxpayers_member_select on public.taxpayers;
create policy taxpayers_member_select
  on public.taxpayers for select
  to authenticated
  using ((select private.has_workspace_role(workspace_id, null)));

drop policy if exists taxpayer_branches_member_select on public.taxpayer_branches;
create policy taxpayer_branches_member_select
  on public.taxpayer_branches for select
  to authenticated
  using ((select private.has_workspace_role(workspace_id, null)));

drop policy if exists invoices_member_select on public.invoices;
create policy invoices_member_select
  on public.invoices for select
  to authenticated
  using ((select private.has_workspace_role(workspace_id, null)));

drop policy if exists cas_journal_entries_member_select on public.cas_journal_entries;
create policy cas_journal_entries_member_select
  on public.cas_journal_entries for select
  to authenticated
  using ((select private.has_workspace_role(workspace_id, null)));

drop policy if exists cas_journal_lines_member_select on public.cas_journal_lines;
create policy cas_journal_lines_member_select
  on public.cas_journal_lines for select
  to authenticated
  using ((select private.has_workspace_role(workspace_id, null)));

drop policy if exists audit_trail_entries_member_select on public.audit_trail_entries;
create policy audit_trail_entries_member_select
  on public.audit_trail_entries for select
  to authenticated
  using ((select private.has_workspace_role(workspace_id, null)));

drop policy if exists erp_webhook_keys_admin_select on public.erp_webhook_keys;
create policy erp_webhook_keys_admin_select
  on public.erp_webhook_keys for select
  to authenticated
  using ((select private.has_workspace_role(workspace_id, array['admin', 'security_officer'])));
