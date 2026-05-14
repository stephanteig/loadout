alter table workspaces enable row level security;
alter table workspace_members enable row level security;
alter table gear enable row level security;
alter table kit_templates enable row level security;
alter table kit_items enable row level security;
alter table shoots enable row level security;
alter table shoot_items enable row level security;

create or replace function is_workspace_member(ws_id uuid)
returns boolean as $$
  select exists (
    select 1 from workspace_members
    where workspace_id = ws_id and user_id = auth.uid()
  );
$$ language sql security definer;

create or replace function is_workspace_editor(ws_id uuid)
returns boolean as $$
  select exists (
    select 1 from workspace_members
    where workspace_id = ws_id
    and user_id = auth.uid()
    and role in ('owner', 'editor')
  );
$$ language sql security definer;

create policy "members can view workspace" on workspaces
  for select using (is_workspace_member(id));

create policy "owner can update workspace" on workspaces
  for update using (owner_id = auth.uid());

create policy "authenticated can create workspace" on workspaces
  for insert with check (owner_id = auth.uid());

create policy "members can view gear" on gear
  for select using (is_workspace_member(workspace_id));

create policy "editors can manage gear" on gear
  for all using (is_workspace_editor(workspace_id));

create policy "members can view kits" on kit_templates
  for select using (is_workspace_member(workspace_id));

create policy "editors can manage kits" on kit_templates
  for all using (is_workspace_editor(workspace_id));

create policy "members can view shoots" on shoots
  for select using (is_workspace_member(workspace_id));

create policy "editors can manage shoots" on shoots
  for all using (is_workspace_editor(workspace_id));

create policy "members can update shoot items" on shoot_items
  for all using (
    exists (
      select 1 from shoots s
      where s.id = shoot_id and is_workspace_member(s.workspace_id)
    )
  );

create policy "public shoot share" on shoots
  for select using (share_token is not null);
