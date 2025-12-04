# AGENTS.md – Canonical Coding Agent Rulebook for VoelgoedEvents

**This file defines EXACTLY how all CODING AGENTS must behave.**  
It is the supreme rulebook. Nothing overrides it.

Agents reading this file must follow every rule exactly, without assumptions, shortcuts, or improvisation.

---

## 0. Role & Scope of the Coding Agent

You are a **CODING AGENT**, not a planner.

- You **do not** design new phases or features.
- You **do not** generate TOON prompts.
- You **do not** decide which domain, resource, or file should be used.

You **receive TOON micro-prompts** that have already decided:

- Which domain slice is involved
- Which resources / workflows / policies must be touched
- Which files must be created/modified
- What the high-level behaviour must be

Your job is to:

- Read the TOON micro-prompt carefully
- Load the relevant `/docs/` files
- Implement the requested changes in clean, production-grade code
- Follow Ash + Phoenix + PETAL best practices
- Enforce multi-tenancy, caching, and performance rules
- Do **no more** and **no less** than what the TOON prompt specifies

If the TOON prompt conflicts with the docs or is ambiguous:  
**You must ask for clarification. You must not guess or “fix” architecture yourself.**

---

## 1. Purpose of This Document

This document defines:

- How coding agents must reason
- What project files they must load before acting
- How they must navigate the codebase
- How to ensure all code follows Ash, Phoenix & Svelte best practices
- How to enforce multi-tenancy, vertical slices, caching, performance
- How to ensure all code output is correct, consistent, and maintainable

**Agents will never generate TOON prompts.**  
**Agents execute TOON prompts created externally.**

---

## 2. Mandatory Workflow (Before ANY Coding)

For every task, the coding agent MUST follow this workflow:

### Step 0 — Read the TOON micro-prompt

- Extract:
  - Task (single responsibility)
  - Objective
  - Exact file paths to touch
  - Domain / resource / workflow / policy being modified
- Do NOT change the scope of the TOON prompt.
- If the TOON prompt is ambiguous or mixes multiple responsibilities, ask the user for clarification rather than silently expanding scope.

### Step 1 — Load root-level AGENTS.md (this file)

- This defines behaviour.
- It overrides everything else.

### Step 2 — Load INDEX.md

Provides:

- Folder map
- File locations
- Where new files must go
- Domain/slice mapping

### Step 3 — Load MASTER_BLUEPRINT.md

Provides:

- Full system vision & architecture
- Domain map
- Feature overview
- Performance architecture

### Step 4 — Load relevant architecture docs

Located in: `/docs/architecture/`

Load **ALL** that apply to the task:

- `01_foundation.md`
- `02_multi_tenancy.md`
- `03_caching_and_realtime.md`
- `04_vertical_slices.md`
- `05_eventing_model.md`
- `06_jobs_and_async.md`
- `07_security_and_auth.md`
- `08_cicd_and_deployment.md`
- `09_scaling_and_resilience.md`

You do **not** redesign architecture.  
You use these docs to ensure your implementation aligns with the existing architecture.

### Step 5 — Load domain docs for the slice being edited

Located in: `/docs/domain/*.md`

**Example:**

- Events → `domain/events_venues.md`
- Seating → `domain/seating.md`
- Scanning → `domain/scanning_devices.md`
- Ticketing → `domain/ticketing_pricing.md`
- Payments → `domain/payments_ledger.md`

Use these to understand invariants, relationships, and domain rules.  
The TOON prompt tells you **which** domain; these docs tell you **how** that domain behaves.

### Step 6 — Load workflow docs for the feature

Located in: `/docs/workflows/*.md`

**Example:**

- "Reserve seat" → `workflows/reserve_seat.md`
- "Complete checkout" → `workflows/complete_checkout.md`
- "Offline sync" → `workflows/offline_scan_sync.md`

You must honour existing workflows. Do not invent new ones unless the TOON prompt explicitly says to.

### Step 7 — Load coding style guidelines for all affected files

Located in: `/docs/coding_style/*.md`

The agent **MUST** load the correct style guide(s):

| File Type                  | Must Load                      |
| -------------------------- | ------------------------------ |
| Elixir business logic      | `elixir_general.md` + `ash.md` |
| Ash resources & validators | `ash.md`                       |
| Phoenix controllers        | `phoenix_liveview.md`          |
| LiveView modules/pages     | `phoenix_liveview.md`          |
| HEEx templates             | `heex.md`                      |
| Tailwind UI                | `tailwind.md`                  |
| JavaScript/TypeScript      | `js_guidelines.md`             |
| Svelte components          | `svelte.md`                    |

If unsure which coding_style doc applies, load ALL of them.

**You must not generate any code until all relevant style guides are loaded.**

### Step 8 — Load .agent rules if using Antigravity

Located in:

- `.agent/rules/`
- `.agent/workflows/`

**Examples:**

- WSL integration
- Mix compile workflow
- Linux command boundaries

### Step 9 — Load Folder-Specific READMEs (Mandatory)

For any file creation or modification, you **MUST** check and adhere to the architectural rules defined in the corresponding folder's `README.md`.

**Example:**

- Before coding workers, check `lib/voelgoedevents/queues/README.md`.
- Before touching infrastructure, check `lib/voelgoedevents/infrastructure/README.md`.

---

## 3. Core Project Principles

### 3.1 Business Logic Rule (Critical)

**All business logic belongs in Ash. Always. No exceptions.**

❌ Do NOT:

- Put business logic in LiveViews
- Put business logic in controllers
- Put domain logic in components
- Call Repo directly (except in seeds/test helpers)

✔ Do:

- Use Ash Resources
- Use Ash Domains
- Use Ash Actions
- Use Ash Validations
- Use Policies for permissions
- Use Calculations & Aggregates
- Use Ash workflows for complex logic

Any attempt to bypass Ash is a violation.

### 3.2 Logical Vertical Slices (Standard Ash Structure)

We use **Logical Vertical Slices** mapped to **Standard Ash Folders**.

- **Mentally**, you work in a slice (e.g., "Ticketing").
- **Physically**, you place files in the standard Ash/Phoenix locations defined in `INDEX.md`.

Do **NOT** create custom folder structures like `lib/voelgoedevents/ticketing/ash/`.  
ALWAYS use `lib/voelgoedevents/ash/resources/ticketing/`.

### 3.3 Multi-Tenancy Enforcement (Never optional)

Every persistent resource MUST:

- Include `organization_id` (or follow the approved multi-tenancy pattern)
- Enforce organization scoping
- Prevent cross-tenant access
- Use Ash policies for authorization
- Keep Redis keys scoped: `org:{org_id}:entity:{id}`

No exceptions.

### 3.4 Caching & Performance Model (Mandatory)

You MUST honour the multi-layer caching specification:

- **Hot:** ETS/GenServer
- **Warm:** Redis
- **Cold:** Postgres

Additionally:

- Redis ZSETs for seat holds
- Redis bitmaps for seat availability
- PubSub for real-time events
- Oban for background jobs
- No DB round-trips on hot paths
- Use indexes and avoid table scans

You must perform a Performance & Scaling Review before finalizing any code.

---

## 4. File Placement Rules

Always use the folder map below (Standard Ash Layout):

| Content category | Specific Location                             |
| ---------------- | --------------------------------------------- |
| Ash Resources    | `lib/voelgoedevents/ash/resources/<slice>/`   |
| Ash Domains      | `lib/voelgoedevents/ash/domains/`             |
| Ash Support      | `lib/voelgoedevents/ash/support/`             |
| Domain contracts | `lib/voelgoedevents/contracts/<slice>/`       |
| Workflows        | `lib/voelgoedevents/workflows/<slice>/`       |
| LiveViews        | `lib/voelgoedevents_web/live/<slice>/`        |
| Controllers      | `lib/voelgoedevents_web/controllers/<slice>/` |
| Components       | `lib/voelgoedevents_web/components/`          |
| Svelte           | `scanner_pwa/src/lib/`                        |
| Migrations       | `priv/repo/migrations`                        |

Never create random or generic folders such as:

- `services`
- `utils`
- `misc`

Everything belongs to a logical slice, placed in the correct standard folder.

---

## 5. Coding Style Enforcement

Before finalizing ANY code, you must:

1. Identify file type
2. Load matching `coding_style` doc(s)
3. Compare the generated code against all style rules
4. Validate:
   - Syntax
   - Naming
   - Folder placement
   - Architectural alignment
   - Multi-tenancy safety
   - Performance rules
   - Ash purity

Correct all violations before responding.

---

## 6. Code Generation Rules

You MUST:

- Write complete, valid, production-ready code
- Use correct file paths
- Maintain consistent naming
- Add clear, intent-focused comments (not narration)
- Never leave placeholders
- Never hallucinate modules or files
- Never invent new architecture
- Implement exactly what the TOON prompt specifies

You MUST NOT:

- Create dead code
- Use inline `<script>` in HEEx
- Add business logic to LiveView
- Use direct `Repo` calls outside Ash
- Break vertical slices
- Use unscoped Redis keys
- Use unsafe or untyped params
- Introduce unapproved dependencies
- Expand scope beyond the TOON micro-prompt

---

## 7. Self-Check Procedure (Mandatory)

Before completing any action, you must run this checklist:

- ✔ Read and understand the TOON micro-prompt  
- ✔ Load AGENTS.md, INDEX.md, MASTER_BLUEPRINT.md  
- ✔ Load architecture docs  
- ✔ Load domain docs  
- ✔ Load workflow docs  
- ✔ Load coding_style docs  
- ✔ Verify correct folder (Standard Ash layout)  
- ✔ Verify Ash purity  
- ✔ Verify multi-tenancy safety  
- ✔ Verify performance rules  
- ✔ Verify logical slice alignment  
- ✔ Verify security constraints  
- ✔ Verify naming consistency  
- ✔ Verify no forbidden patterns  

If any check fails → you must self-correct **before** responding.

---

## 8. Environment Rules (Antigravity / WSL Agents Only)

Agents running in local environments (Antigravity, etc.) MUST:

- Run commands inside WSL using: `wsl bash -l -c "<command>"`
- Navigate to project folder inside WSL: `/home/jcs/projects/voelgoedevents`
- Never run `mix` from Windows paths
- Use `.agent/workflows/mix-compile.md` as the authoritative compile workflow

If a command fails, you must explain why and adjust accordingly.

---

## 9. When the Agent Should Ask Questions

You MUST ask for clarification when:

- The TOON prompt is ambiguous
- A domain action is unclear
- A workflow step is undefined
- A schema or API contract is missing
- A required doc is absent or contradictory
- A feature spans multiple domains
- A style rule conflicts with file content

You must not guess.

---

## 10. Final Rule

**AGENTS.md overrides ALL other files.**

If any other file contradicts this one → AGENTS.md wins.

---

## Summary

This rulebook ensures:

- Consistent code quality across the entire codebase  
- Strict architectural enforcement (Ash, logical slices, multi-tenancy)  
- Performance by design (caching, indexing, event-driven patterns)  
- Security and isolation (organization scoping, policy enforcement)  
- Maintainability (clear folder structure, style consistency)  
- Correctness (no orphaned features, no lost guidance)  
- Clean separation between:
  - **TOON generator** (planning & architecture)
  - **Coding agent** (implementation only)

Agents must follow this rulebook exactly, in every task, without exception.

**Override Level: Supreme – All other files defer to AGENTS.md**
