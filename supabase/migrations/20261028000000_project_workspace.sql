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

create table public.project_galleries (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  project_id uuid not null unique
    references public.projects(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  description text not null default '',
  allow_download boolean not null default false,
  is_active boolean not null default false,
  share_token_hash text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.project_gallery_media (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users(id) on delete cascade,
  gallery_id uuid not null
    references public.project_galleries(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  storage_path text not null unique,
  mime_type text not null check (
    mime_type in (
      'image/jpeg', 'image/png', 'image/webp', 'image/gif',
      'video/mp4', 'video/quicktime', 'video/webm'
    )
  ),
  file_size bigint not null check (file_size between 1 and 104857600),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create index project_gallery_media_gallery_order_idx
  on public.project_gallery_media (gallery_id, sort_order, created_at);

create trigger project_galleries_set_updated_at
before update on public.project_galleries
for each row execute function public.set_updated_at();

alter table public.project_galleries enable row level security;
alter table public.project_gallery_media enable row level security;

create policy "Project galleries are private to their owner"
on public.project_galleries for all to authenticated
using (
  owner_id = auth.uid()
  and exists (
    select 1 from public.projects
    where projects.id = project_galleries.project_id
      and projects.owner_id = auth.uid()
  )
)
with check (
  owner_id = auth.uid()
  and exists (
    select 1 from public.projects
    where projects.id = project_galleries.project_id
      and projects.owner_id = auth.uid()
  )
);

create policy "Gallery media is private to its owner"
on public.project_gallery_media for all to authenticated
using (
  owner_id = auth.uid()
  and exists (
    select 1 from public.project_galleries
    where project_galleries.id = project_gallery_media.gallery_id
      and project_galleries.owner_id = auth.uid()
  )
)
with check (
  owner_id = auth.uid()
  and exists (
    select 1 from public.project_galleries
    where project_galleries.id = project_gallery_media.gallery_id
      and project_galleries.owner_id = auth.uid()
  )
);

grant select, insert, update, delete
  on public.project_galleries to authenticated;
grant select, insert, update, delete
  on public.project_gallery_media to authenticated;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
)
values (
  'project-gallery',
  'project-gallery',
  false,
  104857600,
  array[
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'video/mp4', 'video/quicktime', 'video/webm'
  ]
)
on conflict (id) do nothing;

create policy "Owners can read their private gallery media"
on storage.objects for select to authenticated
using (
  bucket_id = 'project-gallery'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.project_galleries
    where project_galleries.id::text = (storage.foldername(name))[2]
      and project_galleries.owner_id = auth.uid()
  )
);

create policy "Owners can upload their private gallery media"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'project-gallery'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.project_galleries
    where project_galleries.id::text = (storage.foldername(name))[2]
      and project_galleries.owner_id = auth.uid()
  )
);

create policy "Owners can delete their private gallery media"
on storage.objects for delete to authenticated
using (
  bucket_id = 'project-gallery'
  and (storage.foldername(name))[1] = auth.uid()::text
  and exists (
    select 1 from public.project_galleries
    where project_galleries.id::text = (storage.foldername(name))[2]
      and project_galleries.owner_id = auth.uid()
  )
);
