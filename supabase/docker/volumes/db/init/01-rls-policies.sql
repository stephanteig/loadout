-- =============================================================
-- Loadout — Row Level Security policies
-- Updated for 3NF schema (workspace_roles lookup table,
-- clients and locations as separate entities)
-- =============================================================

alter table workspaces        enable row level security;
alter table workspace_members enable row level security;
alter table workspace_roles   enable row level security;
alter table gear_categories   enable row level security;
alter table clients           enable row level security;
alter table locations         enable row level security;
alter table gear              enable row level security;
alter table kit_templates     enable row level security;
alter table kit_items         enable row level security;
alter table shoots            enable row level security;
alter table shoot_items       enable row level security;


-- -------------------------------------------------------------
-- Helper functions
-- Declared SECURITY DEFINER so they run with the permissions
-- of the function owner, bypassing RLS on workspace_members
-- when called from within a policy.
-- -------------------------------------------------------------

create or replace function is_workspace_member(ws_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1
    from workspace_members
    where workspace_id = ws_id
      and user_id = auth.uid()
  );
$$;

create or replace function is_workspace_editor(ws_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1
    from workspace_members wm
    join workspace_roles   wr on wr.id = wm.workspace_role_id
    where wm.workspace_id = ws_id
      and wm.user_id      = auth.uid()
      and wr.name in ('owner', 'editor')
  );
$$;

create or replace function is_workspace_owner(ws_id uuid)
returns boolean
language sql
security definer
stable
as $$
  select exists (
    select 1
    from workspace_members wm
    join workspace_roles   wr on wr.id = wm.workspace_role_id
    where wm.workspace_id = ws_id
      and wm.user_id      = auth.uid()
      and wr.name = 'owner'
  );
$$;


-- -------------------------------------------------------------
-- Lookup tables — readable by everyone (no sensitive data)
-- -------------------------------------------------------------

create policy "public read gear_categories"
  on gear_categories for select using (true);

create policy "public read workspace_roles"
  on workspace_roles for select using (true);


-- -------------------------------------------------------------
-- workspaces
-- -------------------------------------------------------------

create policy "members can view workspace"
  on workspaces for select
  using (is_workspace_member(id));

create policy "authenticated users can create workspace"
  on workspaces for insert
  with check (owner_id = auth.uid());

create policy "owner can update workspace"
  on workspaces for update
  using (owner_id = auth.uid());

create policy "owner can delete workspace"
  on workspaces for delete
  using (owner_id = auth.uid());


-- -------------------------------------------------------------
-- workspace_members
-- -------------------------------------------------------------

create policy "members can view other members"
  on workspace_members for select
  using (is_workspace_member(workspace_id));

create policy "owner can manage members"
  on workspace_members for all
  using (is_workspace_owner(workspace_id));


-- -------------------------------------------------------------
-- clients
-- -------------------------------------------------------------

create policy "members can view clients"
  on clients for select
  using (is_workspace_member(workspace_id));

create policy "editors can manage clients"
  on clients for all
  using (is_workspace_editor(workspace_id));


-- -------------------------------------------------------------
-- locations
-- -------------------------------------------------------------

create policy "members can view locations"
  on locations for select
  using (is_workspace_member(workspace_id));

create policy "editors can manage locations"
  on locations for all
  using (is_workspace_editor(workspace_id));


-- -------------------------------------------------------------
-- gear
-- -------------------------------------------------------------

create policy "members can view gear"
  on gear for select
  using (is_workspace_member(workspace_id));

create policy "editors can manage gear"
  on gear for all
  using (is_workspace_editor(workspace_id));


-- -------------------------------------------------------------
-- kit_templates
-- -------------------------------------------------------------

create policy "members can view kits"
  on kit_templates for select
  using (is_workspace_member(workspace_id));

create policy "editors can manage kits"
  on kit_templates for all
  using (is_workspace_editor(workspace_id));


-- -------------------------------------------------------------
-- kit_items
-- (workspace_id is on the parent kit_template, not here —
--  join through to check membership)
-- -------------------------------------------------------------

create policy "members can view kit items"
  on kit_items for select
  using (
    exists (
      select 1 from kit_templates kt
      where kt.id = kit_id
        and is_workspace_member(kt.workspace_id)
    )
  );

create policy "editors can manage kit items"
  on kit_items for all
  using (
    exists (
      select 1 from kit_templates kt
      where kt.id = kit_id
        and is_workspace_editor(kt.workspace_id)
    )
  );


-- -------------------------------------------------------------
-- shoots
-- -------------------------------------------------------------

create policy "members can view shoots"
  on shoots for select
  using (
    is_workspace_member(workspace_id)
    or share_token is not null   -- public share link
  );

create policy "editors can manage shoots"
  on shoots for all
  using (is_workspace_editor(workspace_id));


-- -------------------------------------------------------------
-- shoot_items
-- -------------------------------------------------------------

create policy "members can view shoot items"
  on shoot_items for select
  using (
    exists (
      select 1 from shoots s
      where s.id = shoot_id
        and is_workspace_member(s.workspace_id)
    )
  );

create policy "members can update shoot items"
  on shoot_items for update
  using (
    exists (
      select 1 from shoots s
      where s.id = shoot_id
        and is_workspace_member(s.workspace_id)
    )
  );

create policy "editors can manage shoot items"
  on shoot_items for all
  using (
    exists (
      select 1 from shoots s
      where s.id = shoot_id
        and is_workspace_editor(s.workspace_id)
    )
  );
