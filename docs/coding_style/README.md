# Coding Style Guide for VoelgoedEvents

## Purpose

This folder defines **language-level and framework-level coding standards** for the VoelgoedEvents platform. It is the authoritative reference for how to write code that respects the project's architecture, constraints, and operational requirements.

## Where This Fits

- **Architecture docs** (`/docs/architecture/*`) define *what* the system looks like structurally.
- **Domain docs** (`/docs/domain/*`) define *what* the business logic does conceptually.
- **Coding style docs** (this folder) define **how code should be written** to implement that architecture correctly.

These docs complement each other. Read the architecture and domain guides first to understand *why* code is organized a certain way. Then read the coding style guides to understand *how* to write code that fits that organization.

## Who Should Read This

- **Human developers**: New and existing team members writing code in the VoelgoedEvents codebase.
- **AI coding agents**: Agents that load these docs as context when generating or modifying code should understand the constraints and patterns they must follow.

## Files in This Folder

### [`elixir_general.md`](./elixir_general.md)
General Elixir coding conventions and best practices. Start here if you're unfamiliar with Elixir idioms. Covers naming, immutability, pattern matching, error handling, and module documentation.

### [`ash.md`](./ash.md)
**Critical guide.** Defines how Ash Framework is used as the sole domain engine in VoelgoedEvents. All business logic—ticketing, seat allocation, payments, multi-tenancy enforcement—flows through Ash resources and actions. This document is the canonical reference for domain-layer code.

### [`phoenix_liveview.md`](./phoenix_liveview.md)
Defines how Phoenix and LiveView are used as thin I/O layers. Covers layout usage, LiveView lifecycle, component patterns, streaming, and how to correctly call Ash domains from LiveViews. No business logic lives here.

### [`heex.md`](./heex.md)
Defines HEEx template syntax rules, best practices, and common patterns. Covers correct interpolation, form binding, loops, and template logic. Focuses on template mechanics and correctness, not styling.

### [`tailwind.md`](./tailwind.md)
Defines how Tailwind CSS is used for styling and layout. Covers utility-first philosophy, class organization, responsive design, accessibility, and VoelgoedEvents-specific design constraints.

### [`svelte.md`](./svelte.md)
Defines how Svelte is used as an optional client-side companion for heavier interactive interfaces. Emphasizes that Svelte is a frontend UI tool only; business logic remains on the backend in Ash. Covers component patterns, API integration, and when to choose Svelte vs LiveView.

### [`js_guidelines.md`](./js_guidelines.md)
Defines JavaScript/TypeScript conventions for any custom JS in the project (hooks, minor client code). Emphasizes minimal custom JS; prefer LiveView and Svelte. Covers structure, style, and integration patterns.

## Key Principles Across All Guides

1. **Ash is the domain engine.** All business logic lives in Ash resources, actions, validations, and changes. No business logic in controllers, LiveViews, or services.

2. **Phoenix/LiveView are I/O layers.** They parse input, call Ash, assign results, and render output. No direct database access; no complex logic.

3. **Vertical slices.** Code is organized by feature, not layer. Each feature owns its Ash domain, Phoenix routes, LiveView, templates, and styling.

4. **Multi-tenancy is non-negotiable.** Every persistent resource includes `organization_id` or equivalent tenant context. All queries, actions, and policies enforce tenant isolation.

5. **Performance by default.** Use the hot/warm/cold caching model (ETS, Redis, Postgres). Cache invalidation is explicit and event-driven.

6. **Real-time by design.** Use PubSub and WebSockets for live updates. Events flow from Ash through the caching layer and out to clients.

7. **Immutability and pattern matching.** Elixir's strengths. Use them consistently.

8. **No magic, no surprises.** Code is explicit, traceable, and easy to reason about. Patterns are consistent across the codebase.

## How to Use These Guides

- **When writing new code**: Skim the relevant style guide (e.g., `ash.md` if writing a new resource, `phoenix_liveview.md` if writing a LiveView handler).
- **During code review**: Reference the appropriate guide to ensure consistency and correctness.
- **When onboarding**: Read these guides alongside the architecture and domain docs to understand the full picture.
- **For AI agents**: Load all guides in `/docs/coding_style/` to understand project-wide constraints and patterns before generating code.

## Related Documentation

- `/docs/project_overview.md` – High-level project description.
- `/docs/platform_overview.md` – Platform features and user flows.
- `/docs/architecture/` – Detailed architectural patterns.
- `/docs/domain/` – Domain-specific logic and invariants.
- `/docs/DOMAIN_MAP.md` – Mapping of domains to modules and resources.

---

*Last updated: 2025-11-25*  
*For questions or updates: Refer to the main project documentation or discuss with the team.*