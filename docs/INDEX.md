# VoelgoedEvents Documentation Index  
**File:** `/docs/INDEX.md`  
**Audience:** Humans & AI Agents  
**Purpose:** Single entry point into all VoelgoedEvents docs

---

## 0. Reading Order for AI Agents (MANDATORY)

If you are an **AI coding or planning agent**, you MUST:

1. Read: `AGENTS.md` (The Supreme Rulebook)
2. Read: `INDEX.md` (This Map)
3. Follow the **"Domain to File Path Mapping"** in Section 4.1 below.

---

## 1. High-Level Orientation

The VoelgoedEvents documentation is designed as a **stack**:

- **Top Layer – What is this platform?** Conceptual understanding, vision, and overall architecture.

- **Middle Layer – How is it structured?** Domains, architecture, workflows, logical slices.

- **Bottom Layer – How do I work with it?** Project setup, coding rules, agent rules, tests, deployment.

This file ties everything together.

---

## 2. Core Entry Documents

These are the **four primary documents** every person or agent should know:

1. **Agent Rules** - `AGENTS.md`  
   - Defines how AI agents must behave, constraints, TOON format, **Standard Ash Folder** rules, and performance/scaling assumptions.

2. **Platform Overview** - `docs/MASTER_BLUEPRINT.md`  
   - Explains what VoelgoedEvents *is*, the product vision, and the "Big Picture" architecture.

3. **Project Guide** - `docs/PROJECT_GUIDE.md`  
   - Explains how to work with the repository: structure, dev environment, commands, workflows.

4. **Domain Map (Authoritative)** - `docs/DOMAIN_MAP.md`  
   - High-level map of all domains: Tenancy, Events, Seating, Ticketing, Payments, Scanning, Analytics.

---

## 3. Human Navigation Path

If you’re a **human developer/architect**, recommended reading order:

1. `MASTER_BLUEPRINT.md`
2. `PROJECT_GUIDE.md`
3. `DOMAIN_MAP.md`
4. `architecture/01_foundation.md`
5. `architecture/04_vertical_slices.md`
6. Then dip into specific domain docs in `docs/domain/*.md`.

---

## 4. AI Agent Navigation Path

If you are an **AI coding agent**, you must:

1. **Load hard constraints:**
   - `AGENTS.md`
   - `architecture/01_foundation.md`
   - `architecture/02_multi_tenancy.md`
   - `architecture/04_vertical_slices.md`

2. **Identify your Logical Slice:**
   - Determine which feature you are working on (e.g., "Ticketing").
   - Use the **Mapping Table below** to find the correct docs and folders.

### 4.1 Domain to File Path Mapping (Standard Ash Layout)

We work in **Logical Slices** but code in **Standard Ash Folders**. Use this map to locate files.

| Logical Slice          | Domain Doc (Read This)             | Ash Resources (Write Here)                                                                  | Workflow Docs (Read Only)      |
|------------------------|------------------------------------|---------------------------------------------------------------------------------------------|--------------------------------|
| **Tenancy & Accounts** | `domain/tenancy_accounts.md`     | `lib/voelgoedevents/ash/resources/accounts/`<br>`lib/voelgoedevents/ash/resources/organizations/` | `docs/workflows/accounts_*.md` |
| **Events & Venues**   | `domain/events_venues.md`         | `lib/voelgoedevents/ash/resources/events/`<br>`lib/voelgoedevents/ash/resources/venues/`       | `docs/workflows/events_*.md`   |
| **Ticketing**         | `domain/ticketing_pricing.md`     | `lib/voelgoedevents/ash/resources/ticketing/`                                                | `docs/workflows/ticketing_*.md` |
| **Seating**           | `domain/seating.md`               | `lib/voelgoedevents/ash/resources/seating/`                                                  | `docs/workflows/seating_*.md`   |
| **Payments**          | `domain/payments_ledger.md`       | `lib/voelgoedevents/ash/resources/payments/`                                                 | `docs/workflows/checkout_*.md`  |
| **Scanning**          | `domain/scanning_devices.md`      | `lib/voelgoedevents/ash/resources/scanning/`                                                 | `docs/workflows/scanning_*.md`  |
| **Analytics**         | `domain/analytics_marketing.md`   | `lib/voelgoedevents/ash/resources/analytics/`                                                | `docs/workflows/analytics_*.md` |


---

## 5. Architecture Documentation

Folder: `/docs/architecture/`  
Index: `/docs/architecture/README.md`

Key files:

- `01_foundation.md` – Core architecture: PETAL, Ash, logical slices.
- `02_multi_tenancy.md` – Multi-tenant rules, org scoping.
- `03_caching_and_realtime.md` – Caching strategy (ETS/Redis).
- `04_vertical_slices.md` – How features are built end-to-end.
- `05_eventing_model.md` – Domain events, PubSub.
- `06_jobs_and_async.md` – Oban jobs.
- `07_security_and_auth.md` – Identity, sessions, API keys.

---

## 6. Domain Documentation

Folder: `/docs/domain/`  
Index: `/docs/domain/README.md`

Use the **Mapping Table in Section 4.1** to choose the right file.

**Note on Duplicate Files:**
- Always prefer the **detailed** file (e.g., `events_venues.md`) over the simple file (`events.md`).
- If a file is empty or just a stub, check for a combined file (e.g., `ticketing_pricing.md` covers both).

---

## 7. Workflow Documentation

Folder: `/docs/workflows/`

Each workflow doc explains an **end-to-end flow** across multiple domains and slices.
Examples: `checkout.md`, `scanning_offline.md`, `refunds.md`.

---

## 8. Agent-Specific Docs

- **`AGENTS.md`**: The Source of Truth.
- **`GEMINI.md`**: Specific instructions for Gemini agents (defer to AGENTS.md).

---

## 9. Summary

1. **Think in Slices** (Logical Boundaries).
2. **Code in Layers** (Ash Standard Folders).
3. **Check AGENTS.md** for every decision.
4. **Use the Map (Section 4.1)** to find your files.

If you are unsure where something belongs:
- Platform-wide concerns → `architecture/`
- Single business capability → `domain/` (Mapped to Ash Resources)
- Multi-step flows → `workflows/`