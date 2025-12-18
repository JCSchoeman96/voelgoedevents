# **AGENTS.md – Canonical Agent Rulebook for VoelgoedEvents**

## Naming hard bans (NON-NEGOTIABLE)

- NEVER use "voelgood" anywhere. It is always a typo.
- Correct forms:
  - "Voelgoed" / "Voelgoodevents" (brand/prose)
  - "voelgoed" / "voelgoodevents" (technical identifiers only when they actually exist in code/paths)

**This file defines EXACTLY how all coding agents must behave.**

It is the **supreme rulebook**. Nothing overrides it.

Agents reading this file **must follow every rule exactly**, without assumptions, shortcuts, improvisation, or “helpful” deviations.

---

## 1. Purpose of This Document

This document defines:

* How coding agents must reason
* What project files must be loaded before acting
* How the codebase must be navigated
* How Ash, Phoenix, and Svelte rules are enforced
* How multi-tenancy, vertical slices, caching, and performance are protected
* How correctness, consistency, and long-term maintainability are guaranteed

### Absolute constraints

* **Agents will NEVER generate TOON prompts**
* **Agents ONLY execute externally-provided TOON prompts**
* Agents may **validate** TOON prompts and **refuse execution** if they violate this rulebook

---

## 2. Beads Workflow (Mandatory, Non-Negotiable)

This repository uses **Beads (`bd`) as the ONLY issue tracker**.

❌ No ad-hoc TODOs
❌ No markdown task lists
❌ No “I’ll remember this later”

If it’s not in Beads, **it does not exist**.

---

### 2.1 Session Start (Mandatory Order)

Before doing **anything**:

```bash
export BEADS_NO_DAEMON=1
git fetch origin
git reset --hard origin/main
bd sync
bd ready --priority 1
```

Then:

```bash
bd show <issue-id>
bd update <issue-id> --status in_progress
```

---

### 2.2 During Work

* Any newly discovered bug / task / gap **must immediately become a Beads issue**:

  ```bash
  bd create "…" -t bug|task|feature -p <0-4> -l <labels>
  ```

* Link it back to the parent:

  ```bash
  bd dep add <new-id> <parent-id> --type discovered-from
  ```

---

### 2.3 Session End (“Land the Plane”)

* Tests must be green if code changed
* Update or close the issue:

  ```bash
  bd close <issue-id> --reason "Fixed"
  ```
* Sync Beads:

  ```bash
  bd sync
  ```

**Commit messages MUST include the Beads issue ID.**

---

## 3. Beads + Git Worktree Hard Rules (CRITICAL)

These rules exist because violating them **will corrupt project state**.

### 3.1 Beads Sync Branch Ownership

* `beads-sync` is **owned exclusively by Beads**
* It lives in a **separate git worktree** at:

```
.git/beads-worktrees/beads-sync
```

### 3.2 Forbidden Git Operations (Never Allowed)

❌ `git checkout beads-sync`
❌ `git reset beads-sync`
❌ `git merge beads-sync`
❌ `git rebase beads-sync`
❌ GitHub UI conflict resolution on `.beads/issues.jsonl`

**Only `bd sync` may modify or push `beads-sync`.**

---

### 3.3 `.beads/issues.jsonl` Is Generated State

* Treat `.beads/issues.jsonl` as **generated, not authored**
* If it conflicts:

  * Discard local edits
  * Run `bd sync`
* **Never “accept both” blindly in GitHub**

If `main` ever points at a Beads merge commit:

```bash
git fetch origin
git reset --hard origin/main
```

Immediately.

---

## 4. Mandatory Load Order (Before ANY Coding)

Agents MUST load the following **in this exact order** before touching code.

### Step 1 — AGENTS.md (This File)

This file supersedes everything else.

---

### Step 2 — INDEX.md

`/docs/INDEX.md`

Provides:

* Folder map
* Canonical file locations
* Domain / slice mapping

---

### Step 3 — MASTER_BLUEPRINT.md

Provides:

* System vision
* Architecture
* Domain boundaries
* Performance model

---

### Step 4 — Architecture Docs

`/docs/architecture/`

Load **ALL that apply**:

* `01_foundation.md`
* `02_multi_tenancy.md`
* `03_caching_and_realtime.md`
* `04_vertical_slices.md`
* `05_eventing_model.md`
* `06_jobs_and_async.md`
* `07_security_and_auth.md`
* `08_cicd_and_deployment.md`
* `09_scaling_and_resilience.md`

---

### Step 5 — Domain Docs

`/docs/domain/*.md`

Load the domain(s) being edited.

---

### Step 6 — Workflow Docs

`/docs/workflows/*.md`

Load the exact workflow(s) touched.

---

### Step 7 — Coding Style Guides

`/docs/coding_style/*.md`

Agents MUST load **all applicable guides**.

| File Type     | Must Load                     |
| ------------- | ----------------------------- |
| Elixir logic  | `elixir_general.md`, `ash.md` |
| Ash resources | `ash.md`                      |
| Ash policies  | `ash.md`, `ash_policies.md`   |
| Phoenix       | `phoenix_liveview.md`         |
| HEEx          | `heex.md`                     |
| Tailwind      | `tailwind.md`                 |
| JS/TS         | `js_guidelines.md`            |
| Svelte        | `svelte.md`                   |

**Ash 3.x only. Deny-by-default policies.**

---

### Step 8 — Folder-Specific READMEs

Before modifying any folder, agents MUST read its `README.md`.

---

## 5. Core Project Principles

### 5.1 Ash Is the Business Layer (Critical)

**ALL business logic lives in Ash. No exceptions.**

❌ LiveViews
❌ Controllers
❌ Components
❌ Direct Repo calls (except seeds/tests)

✔ Ash Resources
✔ Ash Domains
✔ Ash Actions
✔ Policies
✔ Calculations
✔ Aggregates
✔ Workflows

Violations are **hard failures**.

---

### 5.2 Logical Vertical Slices

* Slices are **conceptual**
* Folders are **standardized**
* Never invent new structures

---

### 5.3 Multi-Tenancy (Never Optional)

Every persistent resource MUST:

* Include `organization_id`
* Enforce tenant scoping
* Prevent cross-tenant reads/writes
* Scope Redis keys:

  ```
  org:{org_id}:entity:{id}
  ```

---

### 5.4 Performance Model (Mandatory)

* Hot: ETS / GenServer
* Warm: Redis
* Cold: Postgres

No DB hits on hot paths.
Indexes required.
Scaling impact must be reviewed.

---

### 5.5 Canonical Module Names

Only allowed roots:

* `Voelgoedevents`
* `VoelgoedeventsWeb`

Anything else is **wrong**.

---

## 6. File Placement Rules

Use **Standard Ash Layout only**:

| Category      | Location                                      |
| ------------- | --------------------------------------------- |
| Ash Resources | `lib/voelgoedevents/ash/resources/<slice>/`   |
| Domains       | `lib/voelgoedevents/ash/domains/`             |
| Workflows     | `lib/voelgoedevents/workflows/<slice>/`       |
| LiveViews     | `lib/voelgoedevents_web/live/<slice>/`        |
| Controllers   | `lib/voelgoedevents_web/controllers/<slice>/` |
| Migrations    | `priv/repo/migrations`                        |

❌ `services`
❌ `utils`
❌ `misc`

---

## 7. Coding Rules

Agents MUST:

* Write complete, production-ready code
* Use correct paths and names
* Add intent-based comments
* Ask questions when uncertain

Agents MUST NOT:

* Hallucinate files
* Invent architecture
* Add dead code
* Break slices
* Weaken tenancy
* Introduce unapproved deps

---

## 8. Self-Check Procedure (Mandatory)

Before responding, agents MUST verify:

* Rules loaded
* Docs loaded
* Correct folder
* Ash purity
* Tenancy safety
* Performance safety
* Naming correctness
* No forbidden patterns

Failures require **self-correction**.

---

## 9. Environment Rules (WSL / Local Agents)

* All commands run inside WSL
* Path: `/home/jcs/projects/voelgoedevents`
* Never run `mix` from Windows paths
* Follow `.agent/workflows/mix-compile.md`

---

## 10. When to Ask Questions

Agents MUST ask when:

* Domain intent is unclear
* Workflow is undefined
* Docs conflict
* TOON is ambiguous
* A change spans domains

**Guessing is forbidden.**

---

## 11. Final Rule

**AGENTS.md overrides ALL other files.**

If any file contradicts this → **AGENTS.md wins**.

---

### Override Level: **SUPREME**

This rulebook exists to prevent:

* Architectural drift
* Security regressions
* Tenancy leaks
* Performance collapse
* Beads corruption
* “Clever” mistakes

**Agents must follow it exactly. No exceptions.**

---
