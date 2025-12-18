# Architecture Foundation  
VoelgoedEvents Platform  
**Document: `/docs/architecture/01_foundation.md`**

---

## 1. Purpose of This Document

This document defines the **foundational architecture** of the VoelgoedEvents platform.  
It is the single source of truth for:

- How the system is structured (PETAL stack)
- Why vertical slices are mandatory
- How Ash organizes the domain model
- Multi-tenant boundaries
- The real-time caching + performance stack (ETS, Redis, Postgres)
- Event-driven design (PubSub, async jobs)
- Concurrency, safety, and scalability guarantees
- Rules all developers + AI agents must follow

Nothing in the architecture should conflict with:

- The Domain Map  
- The PETAL Comprehensive Ultimate Build Plan  
- The Performance & Scaling Specification  
- The Vertical Slice Guidelines  
- The VoelgoedEvents Platform Plan  

All design decisions in downstream docs build on this foundation.

---

## 2. Core Architecture Overview

The VoelgoedEvents platform is built on a **PETAL stack**:

- **P**hoenix – delivery layer: HTTP, LiveView, WebSockets, PubSub  
- **E**lixir – runtime, concurrency, OTP processes, ETS  
- **T**ailwindCSS – UI styling  
- **A**sh Framework – domain modeling, actions, authorization  
- **L**iveView – real-time UI, server-driven interactions  

**Ash = the domain engine**  
**Phoenix = the delivery surface**  
**OTP/Redis/Postgres = the performance & consistency engine**

All business logic lives exclusively in **Ash domains**, never controllers, sockets, or components.

---

## 3. Architectural Principles

### 3.1 Vertical Slice Architecture (Mandatory)
Each slice must be:

- Feature-oriented  
- Self-contained  
- Independently deployable  
- Owning its own domain logic, views, actions, routes, caching rules  

A vertical slice links:

UI → LiveView/SvelteKit → Domain Actions → Repo/Cache/State → PubSub → Observers → Workflows

makefile
Copy code

Never:

UI → Controller → Random Repo call → Hand-written business logic

yaml
Copy code

**Slices do not depend on each other horizontally.**  
Slices communicate through **domain events**, **PubSub**, or **explicit interfaces**, not reach-around calls.

---

### 3.2 Ash Domain Purity
Each domain in `/docs/domain/` maps to:

- An Ash Domain module
- A set of Ash Resources
- Actions, not arbitrary functions
- Authorization rules tied to tenancy
- Rich invariants and constraints
- No leakage across domains

Domain boundaries = Enforcement.

---

### 3.3 Multi-tenancy Everywhere (Organization-Scoped)

Every record in every persistent domain includes:

organization_id

markdown
Copy code

Isolation rules:

- No cross-tenant leakage  
- All reads and writes must enforce `organization_id` scoping  
- LiveView sessions must always run inside a tenant context  
- API keys are tenant-specific  
- Redis keys encoded with `{org_id}` where applicable  

---

### 3.4 Performance Tiering Architecture  

The platform operates with **strict hot/warm/cold data separation**:

#### **Hot Layer** — In-memory (ETS, GenServers, process state)
- Nanosecond to microsecond latency  
- Used for:
  - Seat availability snapshots  
  - Membership/RBAC cache  
  - Checkout state  
  - Real-time counters  
  - Pricing pre-computation  
- Volatile; rebuilt from Redis on restart  

#### **Warm Layer** — Redis Cluster  
- Millisecond latency  
- Used for:
  - Seat hold registry (ZSET)  
  - Inventory counters  
  - Scan flags  
  - Rate limits  
  - Funnel events  
  - Job queues  
  - API quota counters  
  - Webhook dedupe  
- Expiring, structured, consistent  

Redis is the **real-time distributed state hub**.

#### **Cold Layer** — Postgres  
- Canonical, durable source  
- Used for:
  - Domain persistence  
  - Ledger correctness  
  - Reporting tables  
  - Historical queries  
- Never used for high-concurrency reads  

---

### 3.5 Real-Time First Architecture

All real-time features use:

- Phoenix PubSub  
- LiveView push updates  
- Presence/registry patterns  
- Redis-backed sequences & counters  
- High-frequency metrics  
- Streaming rather than loading  

Real-time includes:

- Seat availability changes  
- Sales counters  
- Scanning throughput  
- Live dashboards  
- Ticket validation  
- Webhook delivery statuses  

---

### 3.6 Async Workflows (Oban)

Heavy or time-delayed work must be async:

- Report generation  
- Payment reconciliation  
- Webhook retries  
- Notification delivery  
- Segment recomputation  
- Large exports  
- Cache rebuilds  

Vertical slices queue their own jobs into structured Oban queues.  

---

## 4. Code Organization Philosophy

The project structure follows the PETAL plan and vertical slice mapping.

### 4.1 Folder Structure (High-Level)

/lib/voelgoedevents
/domains
/tenancy
/events
/seating
/ticketing
/payments
/scanning
/analytics
/reporting
/notifications
/integrations
/audit
/api
/ephemeral
/services
/web
/controllers
/live
/components
/views

markdown
Copy code

- **domains/** → Ash domains  
- **services/** → adapters for Redis, S3, jobs, external services  
- **web/** → Phoenix delivery layer  

---

## 5. Domain Interaction Model

Domains interact via:

1. **Ash action calls** (when domain-to-domain is required)
2. **Domain events** (Ash resource + action events)
3. **Phoenix PubSub broadcasts**
4. **Redis ephemeral structures**
5. **Oban workflows**
6. **Materialized views / reporting aggregates**

Cross-domain calls are always explicit, documented, and minimal.

---

## 6. Concurrency & Safety Rules

### 6.1 Zero Oversell Guarantee

Seat allocation correctness depends on:

- Redis ZSET holds  
- Seat bitmap  
- Atomic counters  
- Postgres optimistic locking  
- Hot-layer mirrors (ETS)  
- Write-through + read-through caching patterns  

### 6.2 Thundering Herd Protection

Patterns:

- Request coalescing  
- Redis locking tokens  
- Cache stampede protection TTL jitter  
- Read-through ETS  
- Async background refresh  

---

## 7. System-Wide Eventing Model

Every domain publishes events:

- `events:event:{event_id}`
- `ticketing:event:{event_id}`
- `seating:event:{event_id}`
- `payments:order:{order_id}`
- `scanning:session:{session_id}`
- `analytics:event:{event_id}`
- `notifications:org:{org_id}`
- `integrations:incoming:{psp}`
- `reporting:org:{org_id}`
- `api_keys:org:{org_id}`

Events must be:

- Small
- Schema-stable
- Backwards-compatible
- Time-stamped

---

## 8. Error Handling & Resilience

### Levels:

- **Local retries** (Redis atomic corrections)
- **Soft fallbacks** (ETS → Redis → DB)
- **Async remediation** (Oban)
- **Failure isolation** (domain-level boundaries)

### Failure priorities:

1. Never oversell  
2. Never leak cross-tenant data  
3. Never double-charge  
4. Never produce inconsistent ledger entries  
5. Always recover ephemeral state  
6. Always degrade gracefully under load  
7. Always preserve audit trail  

---

## 9. Observability & Metrics Foundation

System-wide telemetry must include:

- Domain events  
- Redis latency  
- Postgres latency  
- ETS hit/miss  
- Cache hit ratios  
- PubSub propagation time  
- Worker queue depth  
- Ticket validation latency  
- Checkout p50/p90/p99  
- Flash-sale throughput  
- API error rates  
- Rate-limit triggers  

Each domain doc specifies its own telemetry in detail.

---

## 10. AI Agent Guidelines

AI coding agents must:

- Follow vertical slice boundaries  
- Never implement business logic outside Ash  
- Use the caching layer rules defined here  
- Respect TTLs, Redis structures, and naming conventions  
- Use Ash resource actions, not manual queries  
- Look up domain-level invariants inside `/docs/domain/*`  
- Treat this file as the architectural root  

All TODOs in domain docs must be resolved here before modification.

---

## 11. Future Architectural Additions

Potential planned enhancements:

- Redis clustering with slot allocation per event  
- ClickHouse or TimescaleDB for advanced analytics  
- Dedicated scanning microservice using WebRTC/WebSocket  
- Multi-region architecture for global events  
- Automated failover for hot-layer state  
- Partitioned Postgres tables for massive ticket volumes  

---

## 12. Summary

This foundation document defines:

- PETAL stack structure  
- Vertical slice mandatory architecture  
- Ash domain boundaries  
- Multi-tenant constraints  
- Real-time + caching architecture  
- Event-driven rules  
- Performance tiers  
- Concurrency guarantees  
- How all domains interact  
- How AI agents must behave  

Every other doc in:

/docs/domain/*
/docs/workflows/*
/docs/architecture/*

vbnet
Copy code

inherits from these principles.
