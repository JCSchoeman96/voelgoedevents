# VoelgoedEvents MVP Scope

## Purpose
Defines the bounded MVP delivery set, anchored in [PROJECT_GUIDE Section 1.2](PROJECT_GUIDE.md#12-mvp-scope-ruthless-version) and constrained by the non-goals in [PROJECT_GUIDE Section 17](PROJECT_GUIDE.md#17-non-goals-for-now).

## MVP INCLUDES (Phases 0–7)
- **Phase 0 – Agent setup & safety rails**: Repository guardrails, environment checks, and documentation alignment to keep delivery predictable.
- **Phase 1 – Technical foundation**: Core PETAL/Ash app, baseline auth, CI wiring, and deployment readiness.
- **Phase 2 – Tenancy, accounts & RBAC**: Single-organization baseline with clear paths to multi-tenant isolation; organization-aware auth and roles.
- **Phase 3 – Core events & GA ticketing**: Event + venue CRUD, general admission ticket types, and pricing suitable for early launches.
- **Phase 4 – Orders, payments & ticket issuance**: Checkout flow, PSP integration, ticket generation, and QR encoding.
- **Phase 5 – Scanning backend & integration**: Scanner APIs, online scanning flows, and device/session tracking to support the PWA shell.
- **Phase 6 – Financial ledger & settlement**: Immutable ledger entries, payouts configuration, and reconciliation-ready reporting.
- **Phase 7 – Organiser admin dashboards**: LiveView admin surfaces for sales, occupancy, and operational controls.

## MVP EXCLUDES
- **Multi-currency or global tax engines** beyond a single-currency launch footprint.
- **Advanced CMS or full website builders**; only lightweight content surfaces required for ticket sales.
- **ERP-grade accounting**; keep finance to settlement-grade ledgers and reconciliations.
- **Heavy SPA front-ends** replacing LiveView; Svelte remains focused on scanner use-cases only.
- **Full multi-tenant SaaS rollout** (white-label, branded domains) beyond the initial single-organization scope.
- **Advanced seating builder and complex pricing packs** beyond basic GA and read-only seat maps.
- **Loyalty, affiliate, or marketplace layers** that extend beyond core ticketing and scanning flows.
