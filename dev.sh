#!/usr/bin/env bash
# =============================================================
# Loadout — dev helper (macOS / Linux)
# Usage: ./dev.sh <command>
# =============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$SCRIPT_DIR/supabase/docker"
COMPOSE="docker compose -f $DOCKER_DIR/docker-compose.yml --env-file $DOCKER_DIR/.env"

# Colours
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[loadout]${RESET} $*"; }
success() { echo -e "${GREEN}[loadout]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[loadout]${RESET} $*"; }
error()   { echo -e "${RED}[loadout] ERROR:${RESET} $*" >&2; exit 1; }
divider() { echo -e "${BOLD}──────────────────────────────────────────${RESET}"; }

# -----------------------------------------------------------
require_env() {
  [[ -f "$DOCKER_DIR/.env" ]] || error ".env not found. Run: ./dev.sh setup"
}

require_docker() {
  command -v docker &>/dev/null || error "Docker not found. Install Docker Desktop."
  docker info &>/dev/null        || error "Docker daemon is not running."
}

# -----------------------------------------------------------
cmd_help() {
  divider
  echo -e "${BOLD}Loadout dev helper${RESET}"
  divider
  echo -e "  ${CYAN}setup${RESET}          Copy .env.example → .env (first-time setup)"
  echo -e "  ${CYAN}up${RESET}             Start all backend services (detached)"
  echo -e "  ${CYAN}down${RESET}           Stop all backend services"
  echo -e "  ${CYAN}restart${RESET}        Stop then start all services"
  echo -e "  ${CYAN}reset${RESET}          Destroy volumes and restart (wipes DB)"
  echo -e "  ${CYAN}logs [service]${RESET} Tail logs (all services, or one: db/auth/kong…)"
  echo -e "  ${CYAN}ps${RESET}             Show running containers"
  echo -e "  ${CYAN}psql${RESET}           Open psql shell in db container"
  echo -e "  ${CYAN}migrate${RESET}        Run SQL migrations against running db"
  echo -e "  ${CYAN}status${RESET}         Health check — all service endpoints"
  echo -e "  ${CYAN}dev${RESET}            Start Vite dev server (frontend)"
  echo -e "  ${CYAN}build${RESET}          Build frontend Docker image"
  echo -e "  ${CYAN}keys${RESET}           Print ANON_KEY and SERVICE_ROLE_KEY from .env"
  divider
}

# -----------------------------------------------------------
cmd_setup() {
  if [[ -f "$DOCKER_DIR/.env" ]]; then
    warn ".env already exists — skipping. Delete it to recreate."
    return
  fi
  cp "$DOCKER_DIR/.env.example" "$DOCKER_DIR/.env"
  success ".env created at supabase/docker/.env"
  echo ""
  warn "Before running 'up' you must:"
  echo "  1. Set POSTGRES_PASSWORD (min 20 chars)"
  echo "  2. Set JWT_SECRET (min 32 chars)"
  echo "  3. Generate ANON_KEY and SERVICE_ROLE_KEY:"
  echo "     https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys"
  echo "  4. Paste keys into supabase/docker/.env"
}

# -----------------------------------------------------------
cmd_up() {
  require_docker
  require_env
  info "Starting backend services…"
  $COMPOSE up -d
  echo ""
  success "Services started."
  divider
  echo -e "  API (Kong):      ${CYAN}http://localhost:8000${RESET}"
  echo -e "  Studio:          ${CYAN}http://localhost:3001${RESET}"
  echo -e "  Postgres:        ${CYAN}localhost:5432${RESET}"
  divider
  info "Frontend: run ${BOLD}./dev.sh dev${RESET} in a separate terminal."
}

# -----------------------------------------------------------
cmd_down() {
  require_docker
  require_env
  info "Stopping backend services…"
  $COMPOSE down
  success "Services stopped."
}

# -----------------------------------------------------------
cmd_restart() {
  cmd_down
  sleep 2
  cmd_up
}

# -----------------------------------------------------------
cmd_reset() {
  require_docker
  require_env
  echo ""
  warn "⚠  This will DESTROY all data (volumes). Type 'yes' to confirm:"
  read -r confirm
  [[ "$confirm" == "yes" ]] || { info "Aborted."; exit 0; }
  $COMPOSE down -v
  success "Volumes removed."
  sleep 2
  cmd_up
}

# -----------------------------------------------------------
cmd_logs() {
  require_docker
  require_env
  local service="${1:-}"
  if [[ -n "$service" ]]; then
    $COMPOSE logs -f "$service"
  else
    $COMPOSE logs -f
  fi
}

# -----------------------------------------------------------
cmd_ps() {
  require_docker
  require_env
  $COMPOSE ps
}

# -----------------------------------------------------------
cmd_psql() {
  require_docker
  require_env
  info "Connecting to Postgres as supabase_admin…"
  $COMPOSE exec db psql -U supabase_admin -d postgres
}

# -----------------------------------------------------------
cmd_migrate() {
  require_docker
  require_env
  info "Running migrations…"
  local init_dir="$DOCKER_DIR/volumes/db/init"
  [[ -d "$init_dir" ]] || error "Init dir not found: $init_dir"

  for f in "$init_dir"/*.sql; do
    info "  → $(basename "$f")"
    $COMPOSE exec -T db psql -U supabase_admin -d postgres < "$f"
  done
  success "Migrations complete."
}

# -----------------------------------------------------------
cmd_status() {
  require_docker
  divider
  echo -e "${BOLD}Service health checks${RESET}"
  divider

  check() {
    local name="$1" url="$2"
    if curl -sf "$url" &>/dev/null; then
      echo -e "  ${GREEN}✓${RESET}  $name"
    else
      echo -e "  ${RED}✗${RESET}  $name  ${YELLOW}($url)${RESET}"
    fi
  }

  check "Kong (API gateway)" "http://localhost:8000/auth/v1/health"
  check "GoTrue (auth)"      "http://localhost:9999/health"   2>/dev/null || true
  check "PostgREST"          "http://localhost:8000/rest/v1/"
  check "Storage"            "http://localhost:8000/storage/v1/status"
  check "Studio"             "http://localhost:3001"
  divider
}

# -----------------------------------------------------------
cmd_dev() {
  info "Starting Vite dev server…"
  cd "$SCRIPT_DIR"
  [[ -f ".env.local" ]] || warn ".env.local not found — VITE_SUPABASE_URL may be unset."
  npm run dev
}

# -----------------------------------------------------------
cmd_build() {
  require_docker
  local tag="${1:-loadout-frontend:latest}"
  local url; url=$(grep VITE_SUPABASE_URL "$SCRIPT_DIR/.env.local" 2>/dev/null | cut -d= -f2 || echo "")
  local key; key=$(grep VITE_SUPABASE_ANON_KEY "$SCRIPT_DIR/.env.local" 2>/dev/null | cut -d= -f2 || echo "")

  [[ -n "$url" ]] || warn "VITE_SUPABASE_URL not found in .env.local — image will use empty URL"
  [[ -n "$key" ]] || warn "VITE_SUPABASE_ANON_KEY not found in .env.local — image will use empty key"

  info "Building frontend image: $tag"
  docker build \
    --build-arg VITE_SUPABASE_URL="$url" \
    --build-arg VITE_SUPABASE_ANON_KEY="$key" \
    -t "$tag" \
    "$SCRIPT_DIR"
  success "Image built: $tag"
}

# -----------------------------------------------------------
cmd_keys() {
  require_env
  echo ""
  echo -e "${BOLD}Keys from supabase/docker/.env${RESET}"
  divider
  grep -E "^(ANON_KEY|SERVICE_ROLE_KEY|JWT_SECRET)" "$DOCKER_DIR/.env" || warn "Keys not set yet."
  divider
}

# -----------------------------------------------------------
# Dispatch
CMD="${1:-help}"
shift || true

case "$CMD" in
  setup)   cmd_setup ;;
  up)      cmd_up ;;
  down)    cmd_down ;;
  restart) cmd_restart ;;
  reset)   cmd_reset ;;
  logs)    cmd_logs "${1:-}" ;;
  ps)      cmd_ps ;;
  psql)    cmd_psql ;;
  migrate) cmd_migrate ;;
  status)  cmd_status ;;
  dev)     cmd_dev ;;
  build)   cmd_build "${1:-}" ;;
  keys)    cmd_keys ;;
  help|--help|-h) cmd_help ;;
  *)       error "Unknown command: $CMD. Run ./dev.sh help" ;;
esac
