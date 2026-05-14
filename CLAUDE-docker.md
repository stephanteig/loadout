# Loadout — Docker & dev workflow instructions for Claude Code

This file tells Claude Code exactly how to interact with Docker and the
development environment. Read this alongside CLAUDE.md.

---

## Dev helper scripts

Two equivalent scripts wrap all Docker and dev commands:

| Platform       | Script     |
|----------------|------------|
| macOS / Linux  | `./dev.sh` |
| Windows        | `.\dev.ps1`|

Claude Code MUST use these scripts instead of calling docker/npm directly.
They handle env file paths, compose file location, and error checking.

---

## Available commands

| Command             | What it does |
|---------------------|--------------|
| `./dev.sh setup`    | Copy `.env.example` → `.env` (run once) |
| `./dev.sh up`       | Start all backend services |
| `./dev.sh down`     | Stop all backend services |
| `./dev.sh restart`  | Stop then start |
| `./dev.sh reset`    | Wipe volumes and restart (destructive) |
| `./dev.sh logs`     | Tail all logs |
| `./dev.sh logs db`  | Tail one service (db/auth/kong/rest/storage/realtime) |
| `./dev.sh ps`       | Show container status |
| `./dev.sh psql`     | Open psql shell |
| `./dev.sh migrate`  | Run SQL files from `volumes/db/init/` |
| `./dev.sh status`   | HTTP health check all endpoints |
| `./dev.sh dev`      | Start Vite dev server |
| `./dev.sh build`    | Build frontend Docker image |
| `./dev.sh keys`     | Print JWT keys from .env |

---

## First-time setup sequence

Claude Code must follow this exact order on a fresh clone:

```bash
# 1. Create .env from template
./dev.sh setup

# 2. STOP — tell the developer to fill in these values manually:
#    - POSTGRES_PASSWORD
#    - JWT_SECRET
#    - ANON_KEY
#    - SERVICE_ROLE_KEY
#    (generate at https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys)

# 3. Copy migration SQL into Docker init directory
cp supabase/migrations/001_init.sql       supabase/docker/volumes/db/init/00-initial-schema.sql
cp supabase/migrations/002_rls_policies.sql supabase/docker/volumes/db/init/01-rls-policies.sql
cp supabase/migrations/003_storage.sql    supabase/docker/volumes/db/init/02-storage.sql

# 4. Start backend
./dev.sh up

# 5. Verify all services are healthy
./dev.sh status

# 6. Start frontend (separate terminal)
./dev.sh dev
```

---

## Day-to-day development

```bash
# Terminal 1 — backend (keep running)
./dev.sh up
./dev.sh logs           # optional: watch logs

# Terminal 2 — frontend
./dev.sh dev

# Check if things are working
./dev.sh status
./dev.sh ps
```

---

## After adding or changing migrations

When a new `.sql` file is added to `supabase/migrations/`:

```bash
# Copy new migration to Docker init dir
cp supabase/migrations/<new_file>.sql supabase/docker/volumes/db/init/<new_file>.sql

# Option A: apply without resetting (if DB is already running)
./dev.sh migrate

# Option B: full reset (destructive — use when schema changes are major)
./dev.sh reset
```

---

## Debugging

```bash
# Tail a specific service
./dev.sh logs kong
./dev.sh logs auth
./dev.sh logs db
./dev.sh logs rest

# Open Postgres directly
./dev.sh psql

# Check which containers are running
./dev.sh ps

# Check API health
./dev.sh status

# Open Studio in browser: http://localhost:3001
```

---

## Environment files

| File | Purpose | Commit? |
|------|---------|---------|
| `supabase/docker/.env.example` | Template — safe to commit | ✅ Yes |
| `supabase/docker/.env` | Real secrets — NEVER commit | ❌ No |
| `.env.local` | Frontend dev env (Vite) | ❌ No |
| `.env.local.example` | Frontend template | ✅ Yes |

Frontend `.env.local` for local dev:
```
VITE_SUPABASE_URL=http://localhost:8000
VITE_SUPABASE_ANON_KEY=<paste ANON_KEY from supabase/docker/.env>
```

---

## Building the frontend image

Only needed when deploying to Azure — not for local dev.

```bash
# Build with keys from .env.local
./dev.sh build

# Build with a specific tag for ACR
./dev.sh build myregistry.azurecr.io/loadout-frontend:v1.0.0

# Push to Azure Container Registry
az acr login --name myregistry
docker push myregistry.azurecr.io/loadout-frontend:v1.0.0
```

---

## Rules for Claude Code

1. Always use `./dev.sh` (or `.\dev.ps1`) — never call `docker compose` directly.
2. Never run `./dev.sh reset` without explicit developer approval.
3. Never modify `supabase/docker/.env` — it is never committed and never touched by code.
4. When adding a migration, ALWAYS copy it to `supabase/docker/volumes/db/init/` as part of the same PR.
5. Prefix init SQL filenames with a two-digit number to control order: `03-new-table.sql`.
6. After schema changes, note in the PR description whether `migrate` or `reset` is required.
