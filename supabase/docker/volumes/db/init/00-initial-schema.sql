-- =============================================================
-- Loadout — Database schema (Third Normal Form)
-- =============================================================
-- Lookup / reference tables first, then core entities,
-- then junction tables. Every non-key attribute depends only
-- on the primary key of its own table (no transitive deps).
-- =============================================================


-- -------------------------------------------------------------
-- LOOKUP TABLES
-- Centralise every repeating, constrained value set.
-- Changes to a value (e.g. renaming a category) require one
-- UPDATE, not a migration or a cascade.
-- -------------------------------------------------------------

create table gear_categories (
  id   smallint    primary key generated always as identity,
  name text        not null unique   -- 'camera', 'lens', 'audio', etc.
);

-- Seed values (stable, shipped with schema)
insert into gear_categories (name) values
  ('camera'),
  ('lens'),
  ('audio'),
  ('light'),
  ('rig'),
  ('power'),
  ('storage'),
  ('wireless'),
  ('misc');


create table workspace_roles (
  id   smallint    primary key generated always as identity,
  name text        not null unique   -- 'owner', 'editor', 'viewer'
);

insert into workspace_roles (name) values
  ('owner'),
  ('editor'),
  ('viewer');


-- -------------------------------------------------------------
-- CORE ENTITIES
-- -------------------------------------------------------------

create table workspaces (
  id         uuid        primary key default gen_random_uuid(),
  name       text        not null,
  owner_id   uuid        not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);


-- Clients are independent entities — a client name should not
-- be repeated across every shoot row (that would be a
-- transitive dependency: shoot_id → client_name via a hidden
-- client concept). Separate table eliminates redundancy and
-- allows renaming a client in one place.
create table clients (
  id           uuid        primary key default gen_random_uuid(),
  workspace_id uuid        not null references workspaces(id) on delete cascade,
  name         text        not null,
  created_at   timestamptz not null default now(),
  unique(workspace_id, name)
);


-- Locations follow the same logic as clients: a location
-- ("Studio Wallin", "Fredrikstad rådhus") is reused across
-- shoots and should be stored once.
create table locations (
  id           uuid        primary key default gen_random_uuid(),
  workspace_id uuid        not null references workspaces(id) on delete cascade,
  name         text        not null,
  address      text,                 -- optional, not repeated per shoot
  created_at   timestamptz not null default now(),
  unique(workspace_id, name)
);


create table gear (
  id                uuid        primary key default gen_random_uuid(),
  workspace_id      uuid        not null references workspaces(id) on delete cascade,
  gear_category_id  smallint    not null references gear_categories(id),
  name              text        not null,
  serial_number     text,
  purchase_price    numeric(10, 2),
  purchase_date     date,
  notes             text,
  image_url         text,
  created_at        timestamptz not null default now()
);


create table kit_templates (
  id           uuid        primary key default gen_random_uuid(),
  workspace_id uuid        not null references workspaces(id) on delete cascade,
  name         text        not null,
  description  text,
  created_by   uuid        references auth.users(id) on delete set null,
  created_at   timestamptz not null default now()
);


create table shoots (
  id               uuid        primary key default gen_random_uuid(),
  workspace_id     uuid        not null references workspaces(id) on delete cascade,
  name             text        not null,
  shoot_date       date,
  location_id      uuid        references locations(id) on delete set null,
  client_id        uuid        references clients(id)   on delete set null,
  kit_template_id  uuid        references kit_templates(id) on delete set null,
  created_by       uuid        references auth.users(id) on delete set null,
  share_token      text        unique default encode(gen_random_bytes(16), 'hex'),
  created_at       timestamptz not null default now()
);


-- -------------------------------------------------------------
-- JUNCTION TABLES
-- -------------------------------------------------------------

-- Members of a workspace.
-- workspace_role_id references the lookup table — role name is
-- stored exactly once, not repeated per row.
create table workspace_members (
  id                  uuid        primary key default gen_random_uuid(),
  workspace_id        uuid        not null references workspaces(id) on delete cascade,
  user_id             uuid        not null references auth.users(id) on delete cascade,
  workspace_role_id   smallint    not null references workspace_roles(id),
  created_at          timestamptz not null default now(),
  unique(workspace_id, user_id)
);


-- Gear items inside a kit template.
create table kit_items (
  id       uuid     primary key default gen_random_uuid(),
  kit_id   uuid     not null references kit_templates(id) on delete cascade,
  gear_id  uuid     not null references gear(id)          on delete cascade,
  notes    text,
  unique(kit_id, gear_id)
);


-- Gear items on a specific shoot day, with checked state.
create table shoot_items (
  id        uuid     primary key default gen_random_uuid(),
  shoot_id  uuid     not null references shoots(id) on delete cascade,
  gear_id   uuid     not null references gear(id)   on delete cascade,
  checked   boolean  not null default false,
  notes     text,
  unique(shoot_id, gear_id)
);


-- -------------------------------------------------------------
-- INDEXES
-- Most FK columns get an index — Postgres does not create them
-- automatically on the referencing side.
-- -------------------------------------------------------------

create index on workspaces        (owner_id);
create index on workspace_members (workspace_id);
create index on workspace_members (user_id);
create index on clients           (workspace_id);
create index on locations         (workspace_id);
create index on gear              (workspace_id);
create index on gear              (gear_category_id);
create index on kit_templates     (workspace_id);
create index on kit_items         (kit_id);
create index on kit_items         (gear_id);
create index on shoots            (workspace_id);
create index on shoots            (client_id);
create index on shoots            (location_id);
create index on shoots            (kit_template_id);
create index on shoot_items       (shoot_id);
create index on shoot_items       (gear_id);
