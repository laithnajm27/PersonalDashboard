create table public.instagram_oauth_states (
  state_hash text primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index instagram_oauth_states_expiry_idx
  on public.instagram_oauth_states (expires_at);

create table public.instagram_connections (
  owner_id uuid primary key references auth.users(id) on delete cascade,
  instagram_user_id text not null,
  username text not null,
  encrypted_access_token text not null,
  token_iv text not null,
  token_expires_at timestamptz not null,
  connected_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index instagram_connections_instagram_user_idx
  on public.instagram_connections (instagram_user_id);

create trigger instagram_connections_set_updated_at
before update on public.instagram_connections
for each row execute function public.set_updated_at();

alter table public.instagram_oauth_states enable row level security;
alter table public.instagram_connections enable row level security;

revoke all on public.instagram_oauth_states from anon, authenticated;
revoke all on public.instagram_connections from anon, authenticated;
