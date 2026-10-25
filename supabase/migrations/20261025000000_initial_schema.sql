create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  unternehmen text,
  instagram_handle text,
  email text,
  telefon text,
  notizen text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kunde_id uuid not null references public.customers(id) on delete restrict,
  titel text not null check (length(trim(titel)) > 0),
  projekt_typ text not null default 'foto'
    check (projekt_typ in ('foto', 'video', 'gespraech', 'kombi')),
  status text not null default 'Offen',
  shotlist_daten jsonb not null default '[]'::jsonb
    check (jsonb_typeof(shotlist_daten) = 'array'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.calendar_entries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  typ text not null check (typ in ('task', 'event')),
  titel text not null check (length(trim(titel)) > 0),
  date_time timestamptz not null,
  erledigt boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index customers_owner_name_idx on public.customers (owner_id, name);
create index projects_owner_created_idx on public.projects (owner_id, created_at desc);
create index projects_customer_idx on public.projects (kunde_id);
create index calendar_owner_date_idx on public.calendar_entries (owner_id, date_time);

create trigger customers_set_updated_at
before update on public.customers
for each row execute function public.set_updated_at();
create trigger projects_set_updated_at
before update on public.projects
for each row execute function public.set_updated_at();
create trigger calendar_entries_set_updated_at
before update on public.calendar_entries
for each row execute function public.set_updated_at();

alter table public.customers enable row level security;
alter table public.projects enable row level security;
alter table public.calendar_entries enable row level security;

create policy "Customers are private to their owner"
on public.customers for all to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

create policy "Projects are private to their owner"
on public.projects for all to authenticated
using (owner_id = auth.uid())
with check (
  owner_id = auth.uid()
  and exists (
    select 1 from public.customers
    where customers.id = projects.kunde_id
      and customers.owner_id = auth.uid()
  )
);

create policy "Calendar entries are private to their owner"
on public.calendar_entries for all to authenticated
using (owner_id = auth.uid())
with check (owner_id = auth.uid());

grant select, insert, update, delete on public.customers to authenticated;
grant select, insert, update, delete on public.projects to authenticated;
grant select, insert, update, delete on public.calendar_entries to authenticated;
