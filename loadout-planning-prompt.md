# Loadout — Claude Code Planning Mode Prompt

Paste this into Claude Code when starting a new session or phase.

---

## Prompt

You are helping build **Loadout**, a PWA for camera gear inventory, kit template management, and shoot day planning. The full project plan is in `CLAUDE.md` at the root of this repo.

**Before writing any code, read `CLAUDE.md` in full.**

### Repo and workspace setup

- The project lives at `~/dev/loadout/`
- If the folder does not exist yet: create the repo from scratch using `npm create vite@latest`, install all dependencies listed in CLAUDE.md, create a new GitHub repo called `loadout` using the `gh` CLI, and push the initial scaffold directly to `main`. This is the only direct push to `main` allowed.
- If the folder already exists: do not reinitialise. Read the current state of the codebase before doing anything.

### Git discipline — read this before touching any file

- After the initial scaffold push, **every change must be a Pull Request**. No exceptions. No direct commits to `main`.
- Workflow for every change:
  1. `git checkout main && git pull`
  2. `git checkout -b <branch-name>` using the naming convention from CLAUDE.md
  3. Make the changes
  4. `git add -A && git commit -m "<descriptive message>"`
  5. `git push origin <branch-name>`
  6. `gh pr create --title "<PR title>" --body "<what changed and why>"`
- After opening the PR, stop. Do not merge. The developer reviews and merges manually.
- Never use `git push origin main`, `git merge`, or `git rebase` directly.

### Planning mode instructions

You are currently in **planning mode**. This means:

1. **Do not write or modify any code yet.**
2. Read the full `CLAUDE.md` and the current state of the codebase.
3. Identify which phase and PR we are currently on based on what already exists.
4. Present a clear plan for the next PR:
   - Branch name
   - Exactly which files will be created or modified
   - What each file will contain at a high level
   - Any Supabase migrations needed
   - Any questions or blockers to resolve before starting
5. Wait for explicit approval before switching out of planning mode and writing code.

If the user says **"go"** or **"start"**, switch to implementation mode and execute the plan exactly as approved. Do not deviate from the approved plan without asking first.

### Supabase

- Project URL and anon key are in `.env.local` (never commit this file)
- Migrations live in `supabase/migrations/` — the full SQL is in CLAUDE.md
- RLS policies are critical — never skip them. All tables must have RLS enabled.
- Storage bucket for gear images is `gear-images` (public bucket)

### Design

- Dark-first: `#0f0f0f` background, `#1a1a1a` surfaces, `#2a2a2a` borders
- Primary accent: `#7F77DD` (purple). Success/checked: `#1D9E75` (teal)
- Tailwind only — no inline styles, no CSS modules
- Mobile-first, bottom nav on mobile
- All user-facing strings in Norwegian

### What to do right now

Read `CLAUDE.md`, check the current state of `~/dev/loadout/`, and tell me:
- What has already been built
- What the next PR should be
- Your plan for that PR

Then wait for me to say "go".

