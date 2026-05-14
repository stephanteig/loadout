# =============================================================
# Loadout — dev helper (Windows PowerShell)
# Usage: .\dev.ps1 <command>
# Requires: Docker Desktop for Windows with WSL2 backend
# =============================================================

param(
    [Parameter(Position=0)]
    [string]$Command = "help",

    [Parameter(Position=1, ValueFromRemainingArguments)]
    [string[]]$Args = @()
)

$ErrorActionPreference = "Stop"

$ScriptDir  = $PSScriptRoot
$DockerDir  = Join-Path $ScriptDir "supabase\docker"
$EnvFile    = Join-Path $DockerDir ".env"
$EnvExample = Join-Path $DockerDir ".env.example"
$InitDir    = Join-Path $DockerDir "volumes\db\init"

function Compose {
    docker compose -f (Join-Path $DockerDir "docker-compose.yml") --env-file $EnvFile @Args
}

# Colours via Write-Host
function Info    { param($msg) Write-Host "[loadout] $msg" -ForegroundColor Cyan }
function Success { param($msg) Write-Host "[loadout] $msg" -ForegroundColor Green }
function Warn    { param($msg) Write-Host "[loadout] $msg" -ForegroundColor Yellow }
function Err     { param($msg) Write-Host "[loadout] ERROR: $msg" -ForegroundColor Red; exit 1 }
function Divider { Write-Host ("─" * 46) -ForegroundColor DarkGray }

function Require-Env {
    if (-not (Test-Path $EnvFile)) { Err ".env not found. Run: .\dev.ps1 setup" }
}

function Require-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Err "Docker not found. Install Docker Desktop."
    }
    $null = docker info 2>&1
    if ($LASTEXITCODE -ne 0) { Err "Docker daemon is not running." }
}

# -----------------------------------------------------------
function Cmd-Help {
    Divider
    Write-Host "Loadout dev helper" -ForegroundColor White
    Divider
    Write-Host "  setup          Copy .env.example to .env (first-time setup)"
    Write-Host "  up             Start all backend services (detached)"
    Write-Host "  down           Stop all backend services"
    Write-Host "  restart        Stop then start all services"
    Write-Host "  reset          Destroy volumes and restart (wipes DB)"
    Write-Host "  logs [svc]     Tail logs (all, or one: db/auth/kong/rest...)"
    Write-Host "  ps             Show running containers"
    Write-Host "  psql           Open psql shell in db container"
    Write-Host "  migrate        Run SQL migrations against running db"
    Write-Host "  status         Health check all service endpoints"
    Write-Host "  dev            Start Vite dev server (frontend)"
    Write-Host "  build [tag]    Build frontend Docker image"
    Write-Host "  keys           Print ANON_KEY and SERVICE_ROLE_KEY from .env"
    Divider
}

# -----------------------------------------------------------
function Cmd-Setup {
    if (Test-Path $EnvFile) {
        Warn ".env already exists — skipping. Delete it to recreate."
        return
    }
    Copy-Item $EnvExample $EnvFile
    Success ".env created at supabase\docker\.env"
    Write-Host ""
    Warn "Before running 'up' you must:"
    Write-Host "  1. Set POSTGRES_PASSWORD (min 20 chars)"
    Write-Host "  2. Set JWT_SECRET (min 32 chars)"
    Write-Host "  3. Generate ANON_KEY and SERVICE_ROLE_KEY:"
    Write-Host "     https://supabase.com/docs/guides/self-hosting/docker#generate-api-keys"
    Write-Host "  4. Paste keys into supabase\docker\.env"
}

# -----------------------------------------------------------
function Cmd-Up {
    Require-Docker; Require-Env
    Info "Starting backend services..."
    Compose up -d
    Write-Host ""
    Success "Services started."
    Divider
    Write-Host "  API (Kong):  http://localhost:8000"
    Write-Host "  Studio:      http://localhost:3001"
    Write-Host "  Postgres:    localhost:5432"
    Divider
    Info "Frontend: run '.\dev.ps1 dev' in a separate terminal."
}

# -----------------------------------------------------------
function Cmd-Down {
    Require-Docker; Require-Env
    Info "Stopping backend services..."
    Compose down
    Success "Services stopped."
}

# -----------------------------------------------------------
function Cmd-Restart {
    Cmd-Down
    Start-Sleep -Seconds 2
    Cmd-Up
}

# -----------------------------------------------------------
function Cmd-Reset {
    Require-Docker; Require-Env
    Write-Host ""
    Warn "This will DESTROY all data (volumes). Type 'yes' to confirm:"
    $confirm = Read-Host
    if ($confirm -ne "yes") { Info "Aborted."; return }
    Compose down -v
    Success "Volumes removed."
    Start-Sleep -Seconds 2
    Cmd-Up
}

# -----------------------------------------------------------
function Cmd-Logs {
    Require-Docker; Require-Env
    $svc = $Args[0]
    if ($svc) { Compose logs -f $svc }
    else       { Compose logs -f }
}

# -----------------------------------------------------------
function Cmd-Ps {
    Require-Docker; Require-Env
    Compose ps
}

# -----------------------------------------------------------
function Cmd-Psql {
    Require-Docker; Require-Env
    Info "Connecting to Postgres as supabase_admin..."
    Compose exec db psql -U supabase_admin -d postgres
}

# -----------------------------------------------------------
function Cmd-Migrate {
    Require-Docker; Require-Env
    if (-not (Test-Path $InitDir)) { Err "Init dir not found: $InitDir" }
    Info "Running migrations..."
    Get-ChildItem $InitDir -Filter "*.sql" | Sort-Object Name | ForEach-Object {
        Info "  -> $($_.Name)"
        Get-Content $_.FullName | Compose exec -T db psql -U supabase_admin -d postgres
    }
    Success "Migrations complete."
}

# -----------------------------------------------------------
function Cmd-Status {
    Require-Docker
    Divider
    Write-Host "Service health checks" -ForegroundColor White
    Divider

    function Check {
        param($name, $url)
        try {
            $null = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
            Write-Host "  [OK]  $name" -ForegroundColor Green
        } catch {
            Write-Host "  [--]  $name  ($url)" -ForegroundColor Red
        }
    }

    Check "Kong (API gateway)" "http://localhost:8000/auth/v1/health"
    Check "PostgREST"          "http://localhost:8000/rest/v1/"
    Check "Storage"            "http://localhost:8000/storage/v1/status"
    Check "Studio"             "http://localhost:3001"
    Divider
}

# -----------------------------------------------------------
function Cmd-Dev {
    Info "Starting Vite dev server..."
    Set-Location $ScriptDir
    if (-not (Test-Path (Join-Path $ScriptDir ".env.local"))) {
        Warn ".env.local not found — VITE_SUPABASE_URL may be unset."
    }
    npm run dev
}

# -----------------------------------------------------------
function Cmd-Build {
    Require-Docker
    $tag = if ($Args[0]) { $Args[0] } else { "loadout-frontend:latest" }
    $envLocal = Join-Path $ScriptDir ".env.local"

    $url = ""
    $key = ""
    if (Test-Path $envLocal) {
        $url = (Get-Content $envLocal | Where-Object { $_ -match "^VITE_SUPABASE_URL=" } | Select-Object -First 1) -replace "^VITE_SUPABASE_URL=",""
        $key = (Get-Content $envLocal | Where-Object { $_ -match "^VITE_SUPABASE_ANON_KEY=" } | Select-Object -First 1) -replace "^VITE_SUPABASE_ANON_KEY=",""
    }

    if (-not $url) { Warn "VITE_SUPABASE_URL not in .env.local — image will use empty URL" }
    if (-not $key) { Warn "VITE_SUPABASE_ANON_KEY not in .env.local — image will use empty key" }

    Info "Building frontend image: $tag"
    docker build `
        --build-arg "VITE_SUPABASE_URL=$url" `
        --build-arg "VITE_SUPABASE_ANON_KEY=$key" `
        -t $tag `
        $ScriptDir
    Success "Image built: $tag"
}

# -----------------------------------------------------------
function Cmd-Keys {
    Require-Env
    Write-Host ""
    Write-Host "Keys from supabase\docker\.env" -ForegroundColor White
    Divider
    Get-Content $EnvFile | Where-Object { $_ -match "^(ANON_KEY|SERVICE_ROLE_KEY|JWT_SECRET)" }
    Divider
}

# -----------------------------------------------------------
# Dispatch
switch ($Command.ToLower()) {
    "setup"   { Cmd-Setup }
    "up"      { Cmd-Up }
    "down"    { Cmd-Down }
    "restart" { Cmd-Restart }
    "reset"   { Cmd-Reset }
    "logs"    { Cmd-Logs }
    "ps"      { Cmd-Ps }
    "psql"    { Cmd-Psql }
    "migrate" { Cmd-Migrate }
    "status"  { Cmd-Status }
    "dev"     { Cmd-Dev }
    "build"   { Cmd-Build }
    "keys"    { Cmd-Keys }
    default   { Cmd-Help }
}
