---
trigger: always_on
---

# Voelgoedevents — Agent Command Allowlist

## Naming Canon (NON-NEGOTIABLE)
- Project/app name: **Voelgoedevents**
- NEVER use: voelgoodevents, VoelgoedEvents
- If an agent prints the wrong casing/spelling, correct it immediately.

## General Execution Rules
- Prefer read-only inspection before edits.
- For any edit: agent MUST provide a plan first (use "PLAN:" section).
- No scope creep: 1 Beads issue = 1 change set.
- If tests fail for a new reason: stop, comment bead, create a new bead, link `discovered-from`.

---

# 1) ALWAYS ALLOWED (SAFE / READ-ONLY)

## Repo navigation + inspection
- `pwd`
- `ls`, `ls -la`
- `cd <path>`
- `cat <file>`, `sed -n '1,200p' <file>`
- `head`, `tail`
- `tree -L <n>` (if installed)
- `find <path> -maxdepth <n> ...` (read-only)

## Searching (fast + safe)
- `rg -n "<pattern>" <path>`
- `rg -n --hidden --glob '!**/.git/**' "<pattern>" <path>`
- `grep -RIn "<pattern>" <path>` (if rg unavailable)

## Git read-only
- `git status -sb`
- `git diff`
- `git diff -- <file>`
- `git log --oneline -n 20`
- `git show <sha>`
- `git branch --show-current`

## Elixir read-only compile/test (allowed; can be slow)
- `mix compile`
- `mix test <path>`
- `mix test <path> --only <tag>`
- `mix test --failed`
- `mix format --check-formatted`
- `mix deps.get`
- `mix deps.tree`
- `mix xref graph --label compile-connected` (if useful)
- `mix ecto.migrations`
- `mix ecto.dump` (read-only output)

---

# 2) ALWAYS ALLOWED (BEADS WORKFLOW COMMANDS)

## Beads: safe day-to-day operations
- `bd status`
- `bd list`
- `bd ready`
- `bd blocked`
- `bd show <id>`
- `bd search "<text>"`
- `bd create "<title>" -t bug|task|feature -p P0|P1|P2|P3|P4 -l <label>... --description "<desc>"`
- `bd update <id> --status open|in_progress|closed`
- `bd update <id> --title "<title>"`
- `bd update <id> --description "<desc>"`
- `bd update <id> --notes "<notes>"`
- `bd update <id> --acceptance "<criteria>"`
- `bd comment <id> "<comment>"`
- `bd dep add <issue_id> <depends_on_id> --type blocks|related|parent-child|discovered-from`
- `bd dep tree <id>`
- `bd dep cycles`
- `bd close <id> --reason "Fixed"|"Done"`
- `bd reopen <id>` (ONLY if regression is proven)
- `bd sync`

### Beads discipline (required)
For any TOON execution:
1) `bd show <id>`
2) `bd update <id> --status in_progress`
3) Do the minimal change
4) Run the KPI test(s)
5) `bd comment <id> ...` including command + result
6) If passing: `bd close <id> --reason "Fixed"`
7) `bd sync`

---

# 3) ALLOWED ONLY WITH EXPLICIT USER CONFIRMATION (RISKY)

## Git that changes history / state
- `git reset --hard ...`
- `git rebase ...`
- `git push --force ...`
- `git clean -fd`
- `git checkout -- <file>` (can discard work)

## Beads destructive / state-altering
- `bd delete ...`
- `bd cleanup`
- `bd compact`
- `bd restore`
- `bd migrate*`
- `bd repair-deps`
- `bd import` / `bd export` (manual use)
- `bd detect-pollution` (can rewrite)
- Anything involving `deletions.jsonl` edits

## Database / migrations that mutate state
- `mix ecto.reset`
- `mix ecto.drop`
- `mix ecto.migrate` (unless Phase 2 step explicitly requires it)
- Direct `psql` UPDATE/DELETE in dev DB
- Any command that edits production/staging DB

---

# 4) FORBIDDEN (NO EXCEPTIONS IN PHASE 2 HARDENING)

- Any command that exfiltrates secrets (printing env files, ssh keys, etc.)
- Any command that disables tenancy boundaries, policies, or FilterByTenant “to make tests pass”
- Any “mass refactor” command touching unrelated files (unless the TOON explicitly scopes it)
- Any attempt to introduce non-canonical names/roles:
  - Canonical roles are exactly: `[:owner, :admin, :staff, :viewer, :scanner_only]`

---

# 5) Agent Planning Requirement
Before any file edit, agent must output:

PLAN:
- Beads Issue: <id>
- Root cause:
- Exact files/lines:
- Minimal edit:
- KPI test command(s):

Then apply the change.

