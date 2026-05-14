create table workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid references auth.users(id) on delete cascade not null,
  created_at timestamptz default now()
);

create table workspace_members (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid references workspaces(id) on delete cascade not null,
  user_id uuid references auth.users(id) on delete cascade not null,
  role text not null check (role in ('owner', 'editor', 'viewer')),
  created_at timestamptz default now(),
  unique(workspace_id, user_id)
);

create table gear (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid references workspaces(id) on delete cascade not null,
  name text not null,
  category text not null check (category in ('camera','lens','audio','light','rig','power','storage','wireless','misc')),
  serial_number text,
  purchase_price numeric,
  purchase_date date,
  notes text,
  image_url text,
  created_at timestamptz default now()
);

create table kit_templates (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid references workspaces(id) on delete cascade not null,
  name text not null,
  description text,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

create table kit_items (
  id uuid primary key default gen_random_uuid(),
  kit_id uuid references kit_templates(id) on delete cascade not null,
  gear_id uuid references gear(id) on delete cascade not null,
  notes text,
  unique(kit_id, gear_id)
);

create table shoots (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid references workspaces(id) on delete cascade not null,
  name text not null,
  shoot_date date,
  location text,
  client text,
  kit_template_id uuid references kit_templates(id) on delete set null,
  created_by uuid references auth.users(id),
  share_token text unique default encode(gen_random_bytes(16), 'hex'),
  created_at timestamptz default now()
);

create table shoot_items (
  id uuid primary key default gen_random_uuid(),
  shoot_id uuid references shoots(id) on delete cascade not null,
  gear_id uuid references gear(id) on delete cascade not null,
  checked boolean default false,
  notes text,
  unique(shoot_id, gear_id)
);
