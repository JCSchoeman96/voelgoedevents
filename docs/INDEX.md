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

## Ops & Debugging

- **IEx Rosetta Stone (Canonical)** — `docs/ops/IEX.md`  
  Interactive debugging reference for VoelgoedEvents (Ash 3.x + multi-tenancy + Redis/ETS/Postgres + workflows).  
  Use this before adding ad-hoc `IO.inspect` or changing code to diagnose production-like issues.

---

## 1. Vision & Planning

**Purpose:** Defines the "Why" and "When". Strategic direction and build sequence.

| Document                                                               | Description                                                                |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| [**MASTER_BLUEPRINT.md**](MASTER_BLUEPRINT.md)                         | **The Vision.** High-level architecture, product goals, and system design. |
| [**PROJECT_GUIDE.md**](PROJECT_GUIDE.md)                               | **The Handbook.** How to run, build, and contribute to the project.        |
| [**VOELGOEDEVENTS_FINAL_ROADMAP.md**](VOELGOEDEVENTS_FINAL_ROADMAP.md) | **The Plan.** Detailed execution roadmap and phase tracking.               |
| [**PRODUCT_VISION.md**](PRODUCT_VISION.md)                             | **Product North Star.** Customer outcomes, positioning, and success metrics. |
| [**MVP_SCOPE.md**](MVP_SCOPE.md)                                       | **Scope Guardrails.** MVP boundaries, assumptions, and exclusions.          |

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
- [**CI/CD & Deployment**](architecture/08_cicd_and_deployment.md)
- [**Scaling & Resilience**](architecture/09_scaling_and_resilience.md)
- [**OTP Architecture**](architecture/10_otp_architecture.md)
- [**Ash-Native Metaprogramming**](architecture/11_ash-native_metaprogramming.md)
- [**Type Safety & Contracts**](architecture/12_type_safety_contracts.md)
- [**PubSub Topics (13_pubsub_topics.md)**](architecture/13_pubsub_topics.md)
- [**Database Index Strategy (14_db_indexes.md)**](architecture/14_db_indexes.md)

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
- [**Accounts (accounts.md)**](domain/accounts.md)
- [**Audit Logging (audit_logging.md)**](domain/audit_logging.md)
- [**Ephemeral / Real-Time State (ephemeral_realtime_state.md)**](domain/ephemeral_realtime_state.md)
- [**Integrations & Webhooks (integrations_webhooks.md)**](domain/integrations_webhooks.md)
- [**Invariants (invariants_global.md)**](domain/invariants_global.md)
- [**Notifications & Delivery (notifications_delivery.md)**](domain/notifications_delivery.md)
- [**Public API & Access Keys (public_api_access_keys.md)**](domain/public_api_access_keys.md)
- [**Reporting (reporting.md)**](domain/reporting.md)
- [**RBAC and Platform Access (rbac_and_platform_access.md)**](domain/rbac_and_platform_access.md)

---

## 4. Platform Delivery & Project Ops

**Purpose:** Execution playbooks for running the project and releases.

| Document                                    | Description                                              |
| ------------------------------------------- | -------------------------------------------------------- |
| [**PROJECT_GUIDE.md**](PROJECT_GUIDE.md)    | **Playbook.** Delivery phases, TOON workflows, and KPIs. |
| [**PROJECT README**](project/README.md)     | **Dev Start.** Quickstart for local development.         |
| [**Environment Setup**](project/environment_setup.md) | **Setup.** Required tools and environment configuration. |
| [**Release Process**](project/release_process.md)     | **Go-Live.** Steps for tagging and shipping releases.    |
| [**Testing Strategy**](project/testing_strategy.md)   | **Quality.** Testing scope, coverage, and ownership.     |
| [**Glossary**](project/glossary.md)                 | **Vocabulary.** Canonical terms and abbreviations.       |
| [**Roadmap (Project)**](project/roadmap.md)          | **Timeline.** Ongoing milestones and deliverables.       |

---

## 5. AI Agent Governance

**Purpose:** The most critical section for current execution flow. Defines the rules for TOON generation.

| Document                                   | Description                                                            |
| ------------------------------------------ | ---------------------------------------------------------------------- |
| [**AGENTS.md**](../AGENTS.md)                 | **The Law.** Supreme rulebook for all AI agents. Overrides everything. |
| [**AI Context Map**](ai/ai_context_map.md) | **The Brain.** Registry of all verified modules, paths, and atoms.     |
| [**GEMINI.md**](../GEMINI.md)                 | **The Persona.** Specific instructions for Gemini agents.              |

---

## 6. APIs & Contracts

**Purpose:** External and internal API specifications.

| Document                                         | Description                                               |
| ------------------------------------------------ | --------------------------------------------------------- |
| [**Public API**](api/public_api.md)              | **External.** Public REST endpoints and usage.            |
| [**Internal API**](api/internal_api.md)          | **Services.** Internal-facing contracts between slices.   |
| [**Scanner API**](api/scanner_api.md)            | **Devices.** Endpoints and flows for scanner apps.        |
| [**Webhook API**](api/webhook_api.md)            | **Events.** Outbound webhook formats and delivery rules.  |
| [**Contracts Reference**](api/contracts_reference.md) | **Types.** Shared contract definitions and schemas.   |

---

## 7. Integrations

**Purpose:** Guidance for connecting to external systems.

| Document                                           | Description                                            |
| -------------------------------------------------- | ------------------------------------------------------ |
| [**Payment Providers**](integration/payment_providers.md) | **Payments.** Supported gateways and integration rules. |
| [**CRM Integrations**](integration/crm_integrations.md)   | **CRM.** Data sync patterns and supported platforms.    |
| [**Marketing & Analytics**](integration/marketing_analytics.md) | **Attribution.** Marketing data capture and flows. |
| [**Exporting Data**](integration/exporting_data.md)       | **Data.** Export formats, schedules, and safeguards.    |
| [**Webhook Delivery**](integration/webhook_delivery.md)   | **Delivery.** Retries, signatures, and failure modes.   |

---

## 8. Technical & Style Guides

### Ash 3.x System Rules (Canonical)
- [**Ash 3 Strict AI Rules**](/docs/ash/ASH_3_AI_STRICT_RULES.md) — Mandatory syntax & actor rules for Ash 3.x  
- [**Ash 3 RBAC Matrix**](/docs/ash/ASH_3_RBAC_MATRIX.md) — Permission matrix, actor shape, policy templates, CI checks  


**Purpose:** Defines the quality standard for all code submissions.

| Document                                          | Description                                                    |
| ------------------------------------------------- | -------------------------------------------------------------- |
| [**Coding Style README**](coding_style/README.md) | **The Standard.** Index of all language-specific style guides. |

### Specific Guides

- [**Elixir General**](coding_style/elixir_general.md)
- [**Ash Framework**](coding_style/ash.md)
- [**Ash Policies**](coding_style/ash_policies.md)
- [**Phoenix & LiveView**](coding_style/phoenix_liveview.md)
- [**HEEx Templates**](coding_style/heex.md)
- [**JavaScript/TypeScript**](coding_style/js_guidelines.md)
- [**Svelte**](coding_style/svelte.md)
- [**Tailwind CSS**](coding_style/tailwind.md)

---

## 9. Workflows

**Purpose:** Orchestration of multi-step business processes.

| Document                                   | Description                                                |
| ------------------------------------------ | ---------------------------------------------------------- |
| [**Workflow README**](workflows/README.md) | **The Flows.** Index of all documented business workflows. |

### Detailed Workflows

- [**complete_checkout.md**](workflows/complete_checkout.md)
- [**funnel_builder.md**](workflows/funnel_builder.md)
- [**offline_sync.md**](workflows/offline_sync.md)
- [**process_scan.md**](workflows/process_scan.md)
- [**release_seat.md**](workflows/release_seat.md)
- [**reserve_seat.md**](workflows/reserve_seat.md)
- [**scanner_offline_sync.md**](workflows/scanner_offline_sync.md)
- [**seat_hold_lifecycle.md**](workflows/seat_hold_lifecycle.md)
- [**seat_hold_registry.md**](workflows/seat_hold_registry.md)
- [**start_checkout.md**](workflows/start_checkout.md)

---

**Last Updated:** 2025-12-11
**Status:** Canonical & Verified
