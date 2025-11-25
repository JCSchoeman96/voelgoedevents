# AGENTS.md – Canonical Agent Rulebook for VoelgoedEvents

**This file defines EXACTLY how all coding agents must behave.**

It is the supreme rulebook. Nothing overrides it.

Agents reading this file must follow every rule exactly, without assumptions, shortcuts, or improvisation.

---

## 1. Purpose of This Document

This document defines:

- How coding agents must reason
- What project files they must load before acting
- How they must navigate the codebase
- How to ensure all code follows Ash, Phoenix & Svelte best practices
- How to enforce multi-tenancy, vertical slices, caching, performance
- And how to ensure all code output is correct, consistent, and maintainable

**Agents will never generate TOON prompts.**

**Agents execute TOON prompts created externally.**

---

## 2. Mandatory Load Order (Before ANY Coding)

Before writing, modifying, deleting, or generating any code, the agent must load the following documents **IN THIS ORDER**:

### Step 1 — Load root-level AGENTS.md (this file)

This defines all behaviour. It supersedes everything else.

### Step 2 — Load INDEX.md

Provides:
- Folder map
- File locations
- Where new files must go
- Vertical slice boundaries

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

### Step 5 — Load domain docs for the slice being edited

Located in: `/docs/domain/*.md`

**Example:**
- Editing events → load `domain/events.md`
- Editing seating → load `domain/seating.md`
- Editing scanning → load `domain/scanning.md`
- Editing ticketing → load `domain/ticketing.md`
- Editing payments → load `domain/payments.md`

### Step 6 — Load workflow docs for the feature

Located in: `/docs/workflows/*.md`

**Example:**
- "Reserve seat" → load `workflows/reserve_seat.md`
- "Complete checkout" → load `workflows/complete_checkout.md`
- "Offline sync" → load `workflows/offline_scan_sync.md`

### Step 7 — Load coding style guidelines for all affected files

Located in: `/docs/coding_style/*.md`

The agent **MUST** load the correct style guide(s):

| File Type                  | Must Load                      |
|----------------------------|--------------------------------|
| Elixir business logic      | `elixir_general.md` + `ash.md` |
| Ash resources & validators | `ash.md`                       |
| Phoenix controllers        | `phoenix_liveview.md`          |
| LiveView modules/pages     | `phoenix_liveview.md`          |
| HEEx templates             | `heex.md`                      |
| Tailwind UI                | `tailwind.md`                  |
| JavaScript/TypeScript      | `js_guidelines.md`             |
| Svelte components          | `svelte.md`                    |

If unsure which coding_style doc applies, load ALL of them.

**Agents must not generate any code until all relevant style guides are loaded.**

### Step 8 — Load .agent rules if using Antigravity

Located in:
- `.agent/rules/`
- `.agent/workflows/`

**Examples:**
- WSL integration
- Mix compile workflow
- Linux command boundaries

---

## 3. Core Project Principles

Agents must always enforce the following global principles.

### 3.1 Business Logic Rule (Critical)

**All business logic belongs in Ash. Always. No exceptions.**

❌ **Do NOT:**
- Put business logic in LiveViews
- Put business logic in controllers
- Put domain logic in components
- Call Repo directly (except in seeds/Test helpers)

✔ **Do:**
- Use Ash Resources
- Use Ash Domains
- Use Ash Actions
- Use Ash Validations
- Use Policies for permissions
- Use Calculations & Aggregates
- Use Ash workflows for complex logic

**Any attempt to bypass Ash is a violation.**

### 3.2 Vertical Slice Architecture (Strict)

All code belongs to a feature slice, not a layer.

Each slice contains:

- Resources
- Domain actions
- Workflows
- Policies
- Contracts
- Controllers (thin I/O)
- LiveViews (thin I/O)
- Components
- Tests

**Agents MUST place files inside the correct slice.**

### 3.3 Multi-Tenancy Enforcement (Never optional)

Every persistent resource **MUST:**

- Include `organization_id`
- Enforce organization scoping
- Prevent cross-tenant access
- Use Ash policies for authorization
- Keep Redis keys scoped: `org:{org_id}:entity:{id}`

**No exceptions.**

### 3.4 Caching & Performance Model (Mandatory)

Agents **MUST** honor the multi-layer caching specification:

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

**Agents must perform a Performance & Scaling Review before finalizing any code.**

---

## 4. File Placement Rules

Agents must always use the folder map in `INDEX.md`.

**Key rules:**

| Content          | Location                                      |
|------------------|-----------------------------------------------|
| Domain logic     | `lib/voelgoedevents/<slice>/ash/`             |
| LiveViews        | `lib/voelgoedevents_web/live/<slice>/`        |
| Controllers      | `lib/voelgoedevents_web/controllers/<slice>/` |
| Components       | `lib/voelgoedevents_web/components/`          |
| Svelte           | `scanner_pwa/src/lib/`                        |
| Migrations       | `priv/repo/migrations`                        |
| Domain contracts | `lib/voelgoedevents/<slice>/contracts/`       |
| Workflows        | `docs/workflows/` or Ash workflow files       |


**Agents must NEVER create random or generic folders such as:**

- `"services"`
- `"utils"`
- `"helpers2"`
- `"misc"`

**Everything belongs to a slice.**

---

## 5. Coding Style Enforcement

Before finalizing **ANY** code, the agent must:

1. Identify file type
2. Load matching `coding_style` doc(s)
3. Compare the generated code against all style rules
4. Validate:
   - Syntax
   - Naming
   - Folder placement
   - Architectural alignment
   - Multi-tenancy safety
   - Performance model
   - Vertical slice boundaries
   - Ash purity

**Correct all violations before responding.**

---

## 6. Code Generation Rules

Agents **must:**

- Write complete, valid, production-ready code
- Use correct file paths
- Maintain consistent naming
- Add clear, intent-focused comments (not narration)
- Never leave placeholders
- Never hallucinate modules or files
- Never invent new architecture
- Ask questions when domain, workflow, or contract details are ambiguous

**Agents must NOT:**

- Create dead code
- Use inline `<script>` in HEEx
- Add business logic to LiveView
- Use direct `Repo` calls outside Ash
- Break vertical slices
- Use unscoped Redis keys
- Use unsafe or untyped params
- Introduce unapproved dependencies

---

## 7. Self-Check Procedure (Mandatory)

Before completing any action, the agent must run this checklist:

- ✔ Load rules (AGENTS.md, INDEX.md, Blueprint)
- ✔ Load architecture docs
- ✔ Load domain docs
- ✔ Load workflow docs
- ✔ Load coding_style docs
- ✔ Verify correct folder
- ✔ Verify Ash purity
- ✔ Verify multi-tenancy safety
- ✔ Verify performance rules
- ✔ Verify vertical slice alignment
- ✔ Verify UI/UX style adherence
- ✔ Verify security constraints
- ✔ Verify naming consistency
- ✔ Verify no forbidden patterns

**If any check fails → the agent must self-correct.**

---

## 8. Environment Rules (Antigravity / WSL Agents Only)

Agents running in local environments (Antigravity, Gemini locally, etc.) **MUST:**

- Run commands inside WSL using: `wsl bash -l -c "<command>"`
- Navigate to project folder inside WSL: `/home/jcs/projects/voelgoedevents`
- Never run mix from Windows paths
- Use `.agent/workflows/mix-compile.md` as the authoritative compile workflow

**If a command fails, agents must explain why and adjust accordingly.**

---

## 9. When the Agent Should Ask Questions

Agents **must** ask for clarification when:

- A domain action is unclear
- A workflow step is undefined
- A schema or API contract is missing
- A required doc is absent or contradictory
- A feature spans multiple domains
- A style rule conflicts with file content
- The TOON prompt is ambiguous

**Agents must not guess.**

---

## 10. Final Rule

**AGENTS.md overrides ALL other files.**

If any other file contradicts this one → **AGENTS.md wins.**

---

## Summary

This rulebook ensures:

✔ Consistent code quality across the entire codebase  
✔ Strict architectural enforcement (Ash, vertical slices, multi-tenancy)  
✔ Performance by design (caching, indexing, event-driven patterns)  
✔ Security and isolation (organization scoping, policy enforcement)  
✔ Maintainability (clear folder structure, style consistency)  
✔ Correctness (no orphaned features, no lost guidance)  

**Agents must follow this rulebook exactly, in every task, without exception.**

---

**Last updated: 2025-11-25**  
**Status: Production-Ready**  
**Override Level: Supreme – All other files defer to AGENTS.md**