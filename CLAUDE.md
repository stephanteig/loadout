# Loadout — Claude Code Project Plan

## Status tracker

> Last updated: 2026-05-14. Local path: `~/Dev/loadout/`

| Phase | PR | Branch | Status |
|-------|----|--------|--------|
| 0 | Scaffold | `main` | ✅ Done |
| 0b | Docker Compose setup | `chore/docker-setup` | ⬜ **Next** |
| 1 | PR 1 — Auth | `feat/auth` | ⬜ Pending |
| 1 | PR 2 — Workspace create | `feat/workspace-create` | ⬜ Pending |
| 1 | PR 3 — Workspace invite | `feat/workspace-invite` | ⬜ Pending |
| 2 | PR 4 — Gear list | `feat/gear-list` | ⬜ Pending |
| 2 | PR 5 — Gear CRUD | `feat/gear-crud` | ⬜ Pending |
| 2 | PR 6 — Gear categories | `feat/gear-categories` | ⬜ Pending |
| 3 | PR 7 — Kit list | `feat/kit-list` | ⬜ Pending |
| 3 | PR 8 — Kit builder | `feat/kit-builder` | ⬜ Pending |
| 4 | PR 9 — Shoot list | `feat/shoot-list` | ⬜ Pending |
| 4 | PR 10 — Shoot create | `feat/shoot-create` | ⬜ Pending |
| 4 | PR 11 — Shoot detail | `feat/shoot-detail` | ⬜ Pending |
| 5 | PR 12 — Share | `feat/shoot-share` | ⬜ Pending |
| 6 | PR 13 — PWA install | `feat/pwa-install-banner` | ⬜ Pending |
| 6 | PR 14 — Polish | `chore/polish` | ⬜ Pending |

### Scaffold — what was done in Phase 0
- Vite + React 18 + Tailwind v4 + Supabase JS client + Zustand + React Router + VitePWA installed
- `vite.config.js`, `src/lib/supabase.js`, `src/index.css` configured
- Migration SQL in `supabase/migrations/` (001, 002, 003)
- Full directory structure scaffolded
- GitHub repo created and pushed to `main`

### Open architectural decision — MUST ASK before starting any backend work

> Recorded: 2026-05-15

The plan (PR #1 `chore/update-plan`) moves the backend to a **self-hosted Supabase stack** (GoTrue + PostgREST + Kong + Storage + Realtime) running in Docker Compose, with `@supabase/supabase-js` as the frontend client.

The developer has not decided whether to keep this approach or **drop the Supabase tooling layer entirely** and use plain PostgreSQL with a custom API (e.g. a lightweight Node/Express or Hono backend instead of PostgREST, and a different auth solution instead of GoTrue).

**Before starting any backend or auth work, ask the developer:**
> "Have you decided whether to keep the self-hosted Supabase stack (GoTrue + PostgREST in Docker) or replace it with plain PostgreSQL and a custom API? This affects Phase 0b, Phase 1 (auth), and the frontend client library."

Do not proceed with Phase 0b (`chore/docker-setup`) or Phase 1 (auth) until this is settled.

---

### Starting a new session — instructions for Claude Code
Read this file in full, then check the status tracker above to find the next `⬜ **Next**` PR. Follow the Git discipline section exactly (branch → commits → PR → stop, do not merge).

---

## Project overview

Loadout is a PWA for camera gear inventory, kit template management, and shoot day planning.

**Frontend**: React 18 + Vite + Tailwind CSS, deployed to Vercel  
**Backend**: Self-hosted Supabase stack via Docker Compose  
**Local path**: `~/Dev/loadout/`  
**Future deployment**: Azure Container Registry → Azure Container Apps

The `@supabase/supabase-js` client is used in the frontend — identical API whether backend runs locally in Docker or in Azure.

---

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  Frontend (Vercel)                                  │
│  React + Vite + Tailwind                            │
│  VITE_SUPABASE_URL → points to backend              │
└───────────────────┬─────────────────────────────────┘
                    │ HTTPS
┌───────────────────▼─────────────────────────────────┐
│  Docker Compose (local) / Azure Container Apps (prod)│
│                                                     │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │ Kong     │  │ GoTrue   │  │ PostgREST        │  │
│  │ (API GW) │  │ (Auth)   │  │ (REST API)       │  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐  │
│  │ Storage  │  │ Realtime │  │ Supabase Studio  │  │
│  │ (images) │  │          │  │ (local only)     │  │
│  └──────────┘  └──────────┘  └──────────────────┘  │
│  ┌────────────────────────────────────────────────┐ │
│  │  PostgreSQL                                    │ │
│  └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

---

## Git discipline — non-negotiable

- The **first push** (initial scaffold) goes directly to `main` — already done
- **Every single change after that** must be a Pull Request — no exceptions, no matter how small
- Claude Code creates the branch, makes the commits, pushes the branch, and opens the PR
- Claude Code never merges PRs — the developer reviews and merges manually
- Branch naming: `feat/`, `fix/`, `chore/` prefixes — e.g. `feat/gear-crud`, `fix/auth-redirect`
- PR titles must be descriptive: what changed and why
- One logical unit of work per PR — do not bundle unrelated changes

---

## Environment variables

### Frontend (`src/.env.local`) — never commit

```bash
# Local development (Docker backend)
VITE_SUPABASE_URL=http://localhost:8000
VITE_SUPABASE_ANON_KEY=<anon-key-from-docker-setup>

# Production (Azure — update when deploying)
# VITE_SUPABASE_URL=https://api.loadout.yourdomain.com
# VITE_SUPABASE_ANON_KEY=<azure-anon-key>
```

Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` to Vercel environment variables when deploying frontend. Point them at the Azure URL, not localhost.

### Backend (`supabase/docker/.env`) — never commit

```bash
POSTGRES_PASSWORD=your-super-secret-postgres-password
JWT_SECRET=your-super-secret-jwt-secret-at-least-32-chars
ANON_KEY=<generate-with-jwt-tool>
SERVICE_ROLE_KEY=<generate-with-jwt-tool>
SITE_URL=http://localhost:3000
ADDITIONAL_REDIRECT_URLS=https://your-vercel-app.vercel.app
API_EXTERNAL_URL=http://localhost:8000
```

---

## Docker Compose setup (Phase 0b)

Create `supabase/docker/` containing the self-hosted Supabase stack.

### File: `supabase/docker/docker-compose.yml`

Based on the official Supabase self-hosted Docker Compose. Key services:

```yaml
# Services (all official Supabase images from docker.io/supabase/)
# - db          postgres:15 with custom init scripts
# - kong        API gateway — exposes port 8000
# - gotrue      Auth server — port 9999
# - postgrest   REST API — port 3000 (internal only, routed via Kong)
# - storage     File storage — port 5000 (internal only)
# - realtime    WebSocket server — port 4000 (internal only)
# - studio      Supabase Studio UI — port 3001 (local dev only)
# - imgproxy    Image transformation — internal only
# - meta        DB metadata — internal only
```

All services communicate on internal Docker network. Only Kong (8000) and Studio (3001) are exposed to host.

### File: `supabase/docker/volumes/db/init/`

Copy migration SQL files here so Postgres runs them on first start:
- `00-initial-schema.sql` — from `supabase/migrations/001_init.sql`
- `01-auth.sql` — from `supabase/migrations/002_rls_policies.sql`
- `02-storage.sql` — from `supabase/migrations/003_storage.sql`

### Generating JWT keys

```bash
# Use this node one-liner to generate keys, or use jwt.io
node -e "
const jose = require('jose');
const secret = 'your-jwt-secret-at-least-32-chars';
// generate anon and service_role JWTs with correct claims
"
```

Or use the official Supabase JWT generator: https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys

### Commands

```bash
# Start all services
cd supabase/docker
docker compose up -d

# View logs
docker compose logs -f kong

# Stop
docker compose down

# Reset database (destructive)
docker compose down -v
docker compose up -d

# Run migrations manually (if containers are already up)
docker compose exec db psql -U postgres -f /docker-entrypoint-initdb.d/00-initial-schema.sql
```

### Ports

| Service | Local URL |
|---------|-----------|
| API Gateway (Kong) | http://localhost:8000 |
| Supabase Studio | http://localhost:3001 |
| PostgreSQL | localhost:5432 |

---

## Project structure

```
loadout/
├── public/
│   ├── icons/                  # PWA icons (192, 512px)
│   └── manifest.json
├── src/
│   ├── components/
│   │   ├── ui/                 # Shared primitives (Button, Badge, Card, Input)
│   │   ├── gear/               # GearCard, GearForm, GearList
│   │   ├── kits/               # KitCard, KitBuilder, KitItem
│   │   ├── shoots/             # ShootCard, ShootForm, ChecklistItem
│   │   └── workspace/          # WorkspaceSelector, MemberRow, InviteModal
│   ├── pages/
│   │   ├── AuthPage.jsx
│   │   ├── DashboardPage.jsx
│   │   ├── GearPage.jsx
│   │   ├── KitsPage.jsx
│   │   ├── ShootsPage.jsx
│   │   ├── ShootDetailPage.jsx
│   │   └── WorkspacePage.jsx
│   ├── lib/
│   │   └── supabase.js
│   ├── stores/
│   │   ├── useGearStore.js
│   │   ├── useKitStore.js
│   │   ├── useShootStore.js
│   │   └── useWorkspaceStore.js
│   ├── hooks/
│   │   ├── useAuth.js
│   │   └── useWorkspace.js
│   ├── App.jsx
│   ├── main.jsx
│   └── index.css
├── supabase/
│   ├── migrations/             # Source of truth SQL
│   │   ├── 001_init.sql
│   │   ├── 002_rls_policies.sql
│   │   └── 003_storage.sql
│   └── docker/                 # Self-hosted Supabase stack
│       ├── docker-compose.yml
│       ├── .env                # never commit — copy from .env.example
│       ├── .env.example
│       └── volumes/
│           ├── db/
│           │   └── init/       # SQL copied from migrations/
│           │       ├── 00-initial-schema.sql
│           │       ├── 01-auth.sql
│           │       └── 02-storage.sql
│           ├── storage/        # persisted file uploads (gitignored)
│           └── logs/           # gitignored
├── .dockerignore
├── .env.local                  # never commit — frontend env
├── .env.local.example
├── .gitignore
├── index.html
├── vite.config.js
└── CLAUDE.md
```

---

## Supabase schema

SQL lives in `supabase/migrations/` and is copied to `supabase/docker/volumes/db/init/` for Docker.

### 001_init.sql
```sql
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
```

### 002_rls_policies.sql
```sql
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
```

### 003_storage.sql
```sql
insert into storage.buckets (id, name, public)
values ('gear-images', 'gear-images', true);

create policy "members can upload gear images" on storage.objects
  for insert with check (
    bucket_id = 'gear-images' and auth.uid() is not null
  );

create policy "public can view gear images" on storage.objects
  for select using (bucket_id = 'gear-images');

create policy "uploaders can delete own images" on storage.objects
  for delete using (
    bucket_id = 'gear-images' and owner = auth.uid()
  );
```

---

## vite.config.js (unchanged)

```js
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icons/*.png'],
      manifest: {
        name: 'Loadout',
        short_name: 'Loadout',
        description: 'Camera gear inventory and shoot planner',
        theme_color: '#0f0f0f',
        background_color: '#0f0f0f',
        display: 'standalone',
        orientation: 'portrait',
        start_url: '/',
        icons: [
          { src: 'icons/icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icons/icon-512.png', sizes: '512x512', type: 'image/png' },
          { src: 'icons/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' }
        ]
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,ico,png,svg}'],
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/.*\/rest\/.*/i,
            handler: 'NetworkFirst',
            options: {
              cacheName: 'api-cache',
              expiration: { maxEntries: 100, maxAgeSeconds: 86400 }
            }
          }
        ]
      }
    })
  ]
})
```

---

## src/lib/supabase.js (unchanged — works with both local Docker and Azure)

```js
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY

export const supabase = createClient(supabaseUrl, supabaseAnonKey)
```

---

## Build phases and PR breakdown

### Phase 0b — Docker Compose (PR: chore/docker-setup)

**Files to create:**
- `supabase/docker/docker-compose.yml` — full Supabase self-hosted stack
- `supabase/docker/.env.example` — template with all required vars
- `supabase/docker/volumes/db/init/00-initial-schema.sql` — copy of 001_init.sql
- `supabase/docker/volumes/db/init/01-auth.sql` — copy of 002_rls_policies.sql
- `supabase/docker/volumes/db/init/02-storage.sql` — copy of 003_storage.sql
- Update `.gitignore` to exclude `supabase/docker/.env` and `supabase/docker/volumes/storage/` and `supabase/docker/volumes/logs/`

**Note:** Use official Supabase self-hosted Docker Compose from https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml as base — do not invent service configs.

---

### Phase 1 — Auth + workspace (PRs 1–3)

**PR 1: `feat/auth`**
- AuthPage with email/password login and signup
- useAuth hook wrapping Supabase auth
- Protected route wrapper
- Redirect to dashboard on login

**PR 2: `feat/workspace-create`**
- WorkspacePage
- Create workspace form
- On creation: insert workspace + insert owner into workspace_members
- useWorkspace hook + useWorkspaceStore

**PR 3: `feat/workspace-invite`**
- Invite member by email (lookup user, insert workspace_members row)
- MemberRow component showing name + role badge
- Role selector (owner/editor/viewer)

---

### Phase 2 — Gear inventory (PRs 4–6)

**PR 4: `feat/gear-list`**
- GearPage with list of gear for active workspace
- GearCard component (name, category badge, serial, thumbnail)
- Filter by category
- useGearStore fetching from Supabase

**PR 5: `feat/gear-crud`**
- GearForm (add and edit)
- Image upload to Supabase Storage
- Delete with confirmation
- Optimistic UI updates in store

**PR 6: `feat/gear-categories`**
- Category filter pills on GearPage
- Category color coding (camera=purple, audio=teal, light=amber, etc.)
- Gear count per category on dashboard

---

### Phase 3 — Kit templates (PRs 7–8)

**PR 7: `feat/kit-list`**
- KitsPage with template cards
- KitCard showing name, item count, created by
- useKitStore

**PR 8: `feat/kit-builder`**
- KitBuilder: select gear from workspace inventory to add to kit
- Add/remove items, per-item notes
- Clone kit (duplicate template + all items)

---

### Phase 4 — Shoot days (PRs 9–11)

**PR 9: `feat/shoot-list`**
- ShootsPage with shoot cards
- ShootCard: name, date, location, client, kit name, progress bar
- useShootStore

**PR 10: `feat/shoot-create`**
- ShootForm: name, date, location, client, optional kit template
- When kit template selected: auto-populate shoot_items from kit_items
- Custom gear selection without template

**PR 11: `feat/shoot-detail`**
- ShootDetailPage with full gear checklist
- Check/uncheck items (update shoot_items.checked)
- Progress bar (checked / total)
- Per-item notes inline edit

---

### Phase 5 — Sharing (PR 12)

**PR 12: `feat/shoot-share`**
- Share button on ShootDetailPage
- Copy shareable link using shoot.share_token
- Public route `/share/:token` — read-only shoot view, no auth required

---

### Phase 6 — PWA + polish (PRs 13–14)

**PR 13: `feat/pwa-install-banner`**
- Detect `beforeinstallprompt` event, store it
- Show install banner at bottom of screen (iOS: manual share instructions, Android: native prompt)
- Dismiss and remember via localStorage
- iOS detection: show "Tap Share → Add to Home Screen"

**PR 14: `chore/polish`**
- Empty states for all pages (no gear, no kits, no shoots)
- Loading skeletons
- Error boundaries
- Toast notifications (gear added, shoot created, etc.)
- Mobile nav bar (bottom tabs: Gear / Kits / Shoots / Workspace)

---

## Azure deployment path (future)

When ready to deploy backend to Azure:

1. Build Docker images: `docker compose build`
2. Tag and push to Azure Container Registry:
   ```bash
   az acr login --name <registry-name>
   docker tag supabase/postgres <registry>.azurecr.io/loadout/postgres:latest
   # repeat for each service
   docker push <registry>.azurecr.io/loadout/postgres:latest
   ```
3. Deploy to Azure Container Apps using the same `docker-compose.yml` as base (Azure supports Compose-to-Container-Apps via `az containerapp compose`)
4. Update `VITE_SUPABASE_URL` in Vercel to point at Azure API gateway URL
5. Update `ADDITIONAL_REDIRECT_URLS` in GoTrue env to include Vercel production URL

**Azure services needed:**
- Azure Container Registry (store images)
- Azure Container Apps (run containers — serverless, scales to zero)
- Azure Database for PostgreSQL Flexible Server (optional — replace container Postgres with managed DB for prod)
- Azure Storage (optional — replace Supabase storage container with Azure Blob Storage)

---

## Design guidelines

- Dark-first UI: background `#0f0f0f`, surfaces `#1a1a1a`, borders `#2a2a2a`
- Accent: `#7F77DD` (purple) for primary actions, `#1D9E75` (teal) for success/checked states
- Typography: system font stack, no external font dependencies
- Category color coding consistent across all views:
  - camera/lens → purple
  - audio → teal
  - light → amber
  - rig → coral
  - power/storage/misc → gray
- Mobile-first layout — bottom nav on mobile, sidebar on desktop (768px breakpoint)
- All forms must work on iOS Safari (avoid fixed positioning issues)

---

## Coding conventions

- Functional components only, no class components
- All Supabase calls inside store actions (Zustand), never directly in components
- Optimistic updates: update store immediately, revert on error
- All user-facing strings in Norwegian
- No unused imports, no console.log in committed code
- Tailwind only — no inline styles, no CSS modules
- File names: PascalCase for components, camelCase for hooks/stores/utils

---

## Deployment — frontend

1. Push to GitHub (all via PRs after initial scaffold)
2. Connect repo to Vercel — auto-deploys on merge to main
3. Add `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` to Vercel environment variables (pointing at Azure when ready)
4. Enable Vercel preview deployments — each open PR gets its own preview URL
