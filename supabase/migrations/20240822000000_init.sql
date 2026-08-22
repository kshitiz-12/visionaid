-- VisionAid++ initial schema + RLS
-- Apply in Supabase SQL editor OR: npx prisma db push (Prisma is source of truth for columns)
-- Enable uuid generator

create extension if not exists "uuid-ossp";

-- profiles.id matches auth.users.id when cloud auth is enabled
create table if not exists public.profiles (
  id uuid primary key,
  full_name text,
  phone text,
  email text,
  preferred_language text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.emergency_contacts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  phone text not null,
  relationship text,
  priority integer not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.favorite_objects (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  object_name text not null,
  description text,
  embedding jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.detection_history (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  object_name text not null,
  confidence double precision,
  distance double precision,
  direction text,
  risk_score double precision,
  context text,
  detected_at timestamptz not null default now()
);

create table if not exists public.voice_history (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  command text not null,
  intent text,
  response text,
  created_at timestamptz not null default now()
);

create table if not exists public.locations (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  name text not null,
  latitude double precision not null,
  longitude double precision not null,
  created_at timestamptz not null default now()
);

create table if not exists public.settings (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null unique references public.profiles (id) on delete cascade,
  indoor_mode boolean not null default false,
  outdoor_mode boolean not null default true,
  voice_speed double precision not null default 1.0,
  voice_volume double precision not null default 1.0,
  language text not null default 'en',
  alert_distance double precision not null default 3.0,
  detection_sensitivity double precision not null default 0.5,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.orders (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  restaurant_name text not null,
  items jsonb not null default '[]'::jsonb,
  total_amount numeric(10, 2) not null default 0,
  status text not null default 'pending',
  created_at timestamptz not null default now()
);

create index if not exists emergency_contacts_user_id_idx on public.emergency_contacts (user_id);
create index if not exists favorite_objects_user_id_idx on public.favorite_objects (user_id);
create index if not exists detection_history_user_id_idx on public.detection_history (user_id);
create index if not exists voice_history_user_id_idx on public.voice_history (user_id);
create index if not exists locations_user_id_idx on public.locations (user_id);
create index if not exists orders_user_id_idx on public.orders (user_id);

alter table public.profiles enable row level security;
alter table public.emergency_contacts enable row level security;
alter table public.favorite_objects enable row level security;
alter table public.detection_history enable row level security;
alter table public.voice_history enable row level security;
alter table public.locations enable row level security;
alter table public.settings enable row level security;
alter table public.orders enable row level security;

-- Users may only read/write their own rows (when using Supabase Auth JWT)
drop policy if exists profiles_own on public.profiles;
create policy profiles_own on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists emergency_contacts_own on public.emergency_contacts;
create policy emergency_contacts_own on public.emergency_contacts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists favorite_objects_own on public.favorite_objects;
create policy favorite_objects_own on public.favorite_objects
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists detection_history_own on public.detection_history;
create policy detection_history_own on public.detection_history
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists voice_history_own on public.voice_history;
create policy voice_history_own on public.voice_history
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists locations_own on public.locations;
create policy locations_own on public.locations
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists settings_own on public.settings;
create policy settings_own on public.settings
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists orders_own on public.orders;
create policy orders_own on public.orders
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
