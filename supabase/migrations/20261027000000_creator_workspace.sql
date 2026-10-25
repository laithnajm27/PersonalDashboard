alter table public.projects
  add column status_updated_at timestamptz not null default now();

create or replace function public.track_project_status_change()
returns trigger
language plpgsql
as $$
begin
  if new.status is distinct from old.status then
    new.status_updated_at = now();
  end if;
  return new;
end;
$$;

create trigger projects_track_status_change
before update on public.projects
for each row execute function public.track_project_status_change();

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  company_name text not null default '',
  company_address text not null default '',
  company_email text not null default '',
  company_phone text not null default '',
  tax_number text not null default '',
  vat_id text not null default '',
  bank_details text not null default '',
  invoice_note text not null default '',
  small_business_default boolean not null default false,
  theme_mode text not null default 'system'
    check (theme_mode in ('light', 'dark', 'system')),
  legal_notice_url text not null default '',
  privacy_url text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.equipment (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  description text not null default '',
  created_at timestamptz not null default now(),
  unique (owner_id, name)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  description text not null default '',
  status text not null default 'open'
    check (status in ('open', 'in_progress', 'done')),
  priority text not null default 'normal'
    check (priority in ('low', 'normal', 'high')),
  due_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.goals (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  description text not null default '',
  due_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.invoice_number_counters (
  owner_id uuid not null references auth.users(id) on delete cascade,
  year integer not null check (year between 2000 and 2100),
  next_number integer not null default 1 check (next_number > 0),
  primary key (owner_id, year)
);

create table public.invoice_documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  year integer not null,
  document_type text not null check (document_type in ('invoice', 'receipt')),
  document_number text not null,
  total numeric(12, 2) not null check (total >= 0),
  snapshot jsonb not null check (jsonb_typeof(snapshot) = 'object'),
  storage_path text unique,
  sha256 text check (sha256 is null or sha256 ~ '^[0-9a-f]{64}$'),
  is_finalized boolean not null default false,
  finalized_at timestamptz,
  unique (owner_id, document_number)
);

create index tasks_owner_due_idx on public.tasks (owner_id, due_at);
create index tasks_owner_status_idx on public.tasks (owner_id, status);
create index goals_owner_due_idx on public.goals (owner_id, due_at);
create index invoices_owner_date_idx
  on public.invoice_documents (owner_id, finalized_at desc);
create index projects_owner_status_date_idx
  on public.projects (owner_id, status, status_updated_at);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();
create trigger tasks_set_updated_at
before update on public.tasks
for each row execute function public.set_updated_at();
create trigger goals_set_updated_at
before update on public.goals
for each row execute function public.set_updated_at();

create or replace function public.create_profile_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', '')
  )
  on conflict (id) do update
    set full_name = excluded.full_name
    where public.profiles.full_name = '';
  return new;
end;
$$;

create trigger auth_user_profile_created
after insert on auth.users
for each row execute function public.create_profile_for_new_user();

alter table public.profiles enable row level security;
alter table public.equipment enable row level security;
alter table public.tasks enable row level security;
alter table public.goals enable row level security;
alter table public.invoice_number_counters enable row level security;
alter table public.invoice_documents enable row level security;

create policy "Profiles are private to their owner"
on public.profiles for all to authenticated
using (id = auth.uid())
with check (id = auth.uid());

create policy "Equipment is private to its owner"
on public.equipment for all to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "Tasks are private to their owner"
on public.tasks for all to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "Goals are private to their owner"
on public.goals for all to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "Invoice counters are not directly readable"
on public.invoice_number_counters for select to authenticated
using (owner_id = auth.uid());

create policy "Invoice documents are read-only to their owner"
on public.invoice_documents for select to authenticated
using (owner_id = auth.uid() and is_finalized);

grant select, insert, update, delete on public.profiles to authenticated;
grant select, insert, update, delete on public.equipment to authenticated;
grant select, insert, update, delete on public.tasks to authenticated;
grant select, insert, update, delete on public.goals to authenticated;
grant select on public.invoice_documents to authenticated;
revoke insert, update, delete on public.invoice_documents from authenticated;
revoke insert, update, delete on public.invoice_number_counters from authenticated;

create or replace function public.reserve_invoice_document(
  p_year integer,
  p_document_type text,
  p_total numeric,
  p_snapshot jsonb
)
returns table (id uuid, document_number text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
  allocated_number integer;
  number_prefix text;
  generated_number text;
  inserted_id uuid;
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;
  if p_year < 2000 or p_year > 2100 then
    raise exception 'Invalid document year';
  end if;
  if p_document_type not in ('invoice', 'receipt') then
    raise exception 'Invalid document type';
  end if;
  if p_total < 0
    or p_total::text in ('NaN', 'Infinity', '-Infinity')
    or jsonb_typeof(p_snapshot) <> 'object'
    or p_snapshot ->> 'document_type' is distinct from p_document_type
    or (p_snapshot ->> 'total')::numeric is distinct from round(p_total, 2)
  then
    raise exception 'Invalid document contents';
  end if;
  insert into public.invoice_number_counters (owner_id, year, next_number)
  values (current_user_id, p_year, 2)
  on conflict (owner_id, year) do update
    set next_number = public.invoice_number_counters.next_number + 1
  returning next_number - 1 into allocated_number;

  number_prefix := case when p_document_type = 'invoice' then 'R' else 'Q' end;
  generated_number := number_prefix || '-' || p_year::text || '-' ||
    lpad(allocated_number::text, 5, '0');

  insert into public.invoice_documents (
    owner_id, year, document_type, document_number, total, snapshot
  )
  values (
    current_user_id, p_year, p_document_type, generated_number, p_total,
    p_snapshot
  )
  returning invoice_documents.id into inserted_id;

  return query select inserted_id, generated_number;
end;
$$;

create or replace function public.complete_invoice_document(
  p_id uuid,
  p_storage_path text,
  p_sha256 text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'Authentication required';
  end if;
  if p_storage_path !~ ('^' || current_user_id::text || '/[0-9a-f-]+\.pdf$') then
    raise exception 'Invalid document storage path';
  end if;
  if p_sha256 !~ '^[0-9a-f]{64}$' then
    raise exception 'Invalid document checksum';
  end if;
  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'invoice-pdfs'
      and name = p_storage_path
  ) then
    raise exception 'Invoice PDF upload was not found';
  end if;

  update public.invoice_documents
  set storage_path = p_storage_path,
      sha256 = p_sha256,
      is_finalized = true,
      finalized_at = now()
  where id = p_id
    and owner_id = current_user_id
    and not is_finalized;
  if not found then
    raise exception 'Document not found or already finalized';
  end if;
end;
$$;

revoke all on function public.reserve_invoice_document(
  integer, text, numeric, jsonb
) from public, anon;
grant execute on function public.reserve_invoice_document(
  integer, text, numeric, jsonb
) to authenticated;
revoke all on function public.complete_invoice_document(
  uuid, text, text
) from public, anon;
grant execute on function public.complete_invoice_document(
  uuid, text, text
) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('invoice-pdfs', 'invoice-pdfs', false, 10485760, array['application/pdf'])
on conflict (id) do nothing;

create policy "Owners can read their invoice PDFs"
on storage.objects for select to authenticated
using (
  bucket_id = 'invoice-pdfs'
  and (storage.foldername(name))[1] = auth.uid()::text
);

create policy "Owners can upload their invoice PDFs"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'invoice-pdfs'
  and (storage.foldername(name))[1] = auth.uid()::text
);
