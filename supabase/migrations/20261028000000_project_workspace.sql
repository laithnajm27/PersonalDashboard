alter table public.projects
  add column beschreibung text not null default '',
  add column ort text not null default '',
  add column start_at timestamptz,
  add column due_at timestamptz,
  add column budget numeric(12, 2)
    check (budget is null or budget >= 0);

create table public.project_links (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  project_id uuid not null
    references public.projects(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  url text not null check (url ~ '^https?://[^[:space:]]+$'),
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.tasks
  add column project_id uuid references public.projects(id) on delete set null;

create index project_links_owner_project_idx
  on public.project_links (owner_id, project_id, created_at);
create index tasks_owner_project_idx
  on public.tasks (owner_id, project_id, due_at);

create trigger project_links_set_updated_at
before update on public.project_links
for each row execute function public.set_updated_at();

alter table public.project_links enable row level security;

create policy "Project links are private to their project owner"
on public.project_links for all to authenticated
using (
  owner_id = auth.uid()
  and exists (
    select 1 from public.projects
    where projects.id = project_links.project_id
      and projects.owner_id = auth.uid()
  )
)
with check (
  owner_id = auth.uid()
  and exists (
    select 1 from public.projects
    where projects.id = project_links.project_id
      and projects.owner_id = auth.uid()
  )
);

drop policy "Tasks are private to their owner" on public.tasks;
create policy "Tasks are private to their owner"
on public.tasks for all to authenticated
using (
  owner_id = auth.uid()
  and (
    project_id is null
    or exists (
      select 1 from public.projects
      where projects.id = tasks.project_id
        and projects.owner_id = auth.uid()
    )
  )
)
with check (
  owner_id = auth.uid()
  and (
    project_id is null
    or exists (
      select 1 from public.projects
      where projects.id = tasks.project_id
        and projects.owner_id = auth.uid()
    )
  )
);

grant select, insert, update, delete on public.project_links to authenticated;
