# VoelgoedEvents Documentation Index

**File:** `/docs/INDEX.md`
**Audience:** Humans & AI Agents
**Purpose:** Canonical Entry Point and Navigational Hub for the VoelgoedEvents documentation ecosystem.

---

## 0. The Golden Rule for AI Agents

If you are an **AI coding or planning agent**, you **MUST** consult this file first.
This is your **Sitemap**. Do not guess file paths. Do not hallucinate documents.
Use the links below to find the authoritative source for any topic.

---

## 1. Vision & Planning

**Purpose:** Defines the "Why" and "When". Strategic direction and build sequence.

| Document                                                               | Description                                                                |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| [**MASTER_BLUEPRINT.md**](MASTER_BLUEPRINT.md)                         | **The Vision.** High-level architecture, product goals, and system design. |
| [**PROJECT_GUIDE.md**](PROJECT_GUIDE.md)                               | **The Handbook.** How to run, build, and contribute to the project.        |
| [**VOELGOEDEVENTS_FINAL_ROADMAP.md**](VOELGOEDEVENTS_FINAL_ROADMAP.md) | **The Plan.** Detailed execution roadmap and phase tracking.               |

---

## 2. Architectural Core

**Purpose:** Defines the "How" for systems and high-level structure.

| Document                                          | Description                                                                         |
| ------------------------------------------------- | ----------------------------------------------------------------------------------- |
| [**ARCHITECTURE.md**](ARCHITECTURE.md)            | **The System.** Core architectural decisions and patterns.                          |
| [**Architecture README**](architecture/README.md) | **Deep Dive.** Index of specific architectural components (Tenancy, Caching, etc.). |

### Critical Architecture Specs

- [**Foundation (PETAL Stack)**](architecture/01_foundation.md)
- [**Multi-Tenancy**](architecture/02_multi_tenancy.md)
- [**Caching & Realtime**](architecture/03_caching_and_realtime.md)
- [**Vertical Slices**](architecture/04_vertical_slices.md)
- [**Eventing Model**](architecture/05_eventing_model.md)
- [**Jobs & Async (Oban)**](architecture/06_jobs_and_async.md)
- [**Security & Auth**](architecture/07_security_and_auth.md)

---

## 3. Domain Modeling

**Purpose:** Defines the "What". The single source for entities, relationships, and invariants.

| Document                              | Description                                                                 |
| ------------------------------------- | --------------------------------------------------------------------------- |
| [**DOMAIN_MAP.md**](DOMAIN_MAP.md)    | **The Map.** High-level visual guide to all domains and their interactions. |
| [**Domain README**](domain/README.md) | **The Details.** Index of deep-dive domain specifications.                  |

### Key Domains

- [**Tenancy & Accounts**](domain/tenancy_accounts.md)
- [**Events & Venues**](domain/events_venues.md)
- [**Ticketing & Pricing**](domain/ticketing_pricing.md)
- [**Seating**](domain/seating.md)
- [**Payments & Ledger**](domain/payments_ledger.md)
- [**Scanning & Devices**](domain/scanning_devices.md)
- [**Analytics & Marketing**](domain/analytics_marketing.md)

---

## 4. AI Agent Governance

**Purpose:** The most critical section for current execution flow. Defines the rules for TOON generation.

| Document                                   | Description                                                            |
| ------------------------------------------ | ---------------------------------------------------------------------- |
| [**AGENTS.md**](AGENTS.md)                 | **The Law.** Supreme rulebook for all AI agents. Overrides everything. |
| [**AI Context Map**](ai/ai_context_map.md) | **The Brain.** Registry of all verified modules, paths, and atoms.     |
| [**GEMINI.md**](GEMINI.md)                 | **The Persona.** Specific instructions for Gemini agents.              |

---

## 5. Technical & Style Guides

**Purpose:** Defines the quality standard for all code submissions.

| Document                                          | Description                                                    |
| ------------------------------------------------- | -------------------------------------------------------------- |
| [**Coding Style README**](coding_style/README.md) | **The Standard.** Index of all language-specific style guides. |

### Specific Guides

- [**Elixir General**](coding_style/elixir_general.md)
- [**Ash Framework**](coding_style/ash.md)
- [**Phoenix & LiveView**](coding_style/phoenix_liveview.md)
- [**HEEx Templates**](coding_style/heex.md)
- [**JavaScript/TypeScript**](coding_style/js_guidelines.md)
- [**Svelte**](coding_style/svelte.md)
- [**Tailwind CSS**](coding_style/tailwind.md)

---

## 6. Workflows

**Purpose:** Orchestration of multi-step business processes.

| Document                                   | Description                                                |
| ------------------------------------------ | ---------------------------------------------------------- |
| [**Workflow README**](workflows/README.md) | **The Flows.** Index of all documented business workflows. |

---

**Last Updated:** 2025-12-02
**Status:** Canonical & Verified
