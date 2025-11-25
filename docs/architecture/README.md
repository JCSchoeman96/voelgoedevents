# Architecture Documentation  
**Folder:** `/docs/architecture/`  
**Purpose:** Authoritative reference for all architectural decisions in VoelgoedEvents  
**Audience:** Architects • Senior Developers • AI Coding Agents • Engineering Leads  

---

# 1. Overview

The `/docs/architecture/` directory contains the **complete architectural foundation** of the VoelgoedEvents platform.

These documents represent:

- The **platform’s non-negotiable constraints**
- The **system design principles**
- The **rules that guide vertical slices and domains**
- How the platform scales, secures, caches, and processes data  
- How real-time flows operate end-to-end  
- How deployments and async jobs integrate with the system  

This folder acts as the **architectural guidebook** that governs all implementation work.

No feature, slice, or domain decision may violate the architectural rules defined here.

---

# 2. Contents of This Directory

Below is the full list of architecture documents and their purpose:

---

## **01_foundation.md**  
**What it is:**  
The “master architectural blueprint” of VoelgoedEvents.

**Covers:**  
- Core architectural philosophy  
- PETAL stack rationale  
- Domain-driven structure (Ash)  
- Caching tiers and system responsibilities  
- Real-time expectations  
- Resilience & concurrency guarantees  
- Why vertical slices exist  

**Use When:**  
Understanding the platform’s overarching architecture.

---

## **02_multi_tenancy.md**  
**What it is:**  
The complete multi-tenant isolation model.

**Covers:**  
- Tenant boundaries  
- Organization scoping  
- Authorization & Ash policy rules  
- Database indexes for multi-tenancy  
- Redis + ETS namespacing  
- Cross-tenant safety constraints  
- Tenant-specific PubSub channels  

**Use When:**  
Building features for organizations, roles, device management, API keys, or anything that touches tenant-based data.

---

## **03_caching_and_realtime.md**  
**What it is:**  
The performance-critical caching model that ensures real-time behavior.

**Covers:**  
- Hot → Warm → Cold architecture  
- ETS mirroring  
- Redis bitmaps, ZSETs, lists, streams  
- Postgres consistency rules  
- Cache invalidation  
- Flash-sale readiness  
- How UI receives real-time updates  

**Use When:**  
Working on seat maps, scanning, dashboards, analytics, or any performance-sensitive feature.

---

## **04_vertical_slices.md**  
**What it is:**  
The development model that drives the entire codebase.

**Covers:**  
- Vertical slice structure  
- Why slices exist (vs. layers)  
- Enforcement rules  
- Inter-slice boundaries  
- Folder layout requirements  
- Testing & observability in slices  

**Use When:**  
Building new features, doing domain orchestration, designing end-to-end flows.

---

## **05_eventing_model.md**  
**What it is:**  
The unified event-driven architecture for VoelgoedEvents.

**Covers:**  
- Domain events (Ash)  
- System events (PubSub)  
- Redis Streams for analytics  
- Webhook event delivery  
- Workflow events (jobs)  
- Event propagation guarantees  
- Real-time fanout model  

**Use When:**  
Designing LiveView updates, ticketing workflows, scanning logic, notifications, analytics, or any reactive features.

---

## **06_jobs_and_async.md**  
**What it is:**  
The async workflow and background job architecture.

**Covers:**  
- How and when to use Oban  
- Queue naming rules  
- Idempotency guarantees  
- Retry logic & backoff  
- DLQ rules  
- Integration with Redis & caching  
- Domain-specific async workflows  

**Use When:**  
Working on payments, notifications, reconciliation, exports, reports, device sync, and anything long-running.

---

## **07_security_and_auth.md**  
**What it is:**  
The platform’s security, authentication, and authorization architecture.

**Covers:**  
- Identity types (users, devices, API clients)  
- RBAC model  
- Token & session rules  
- Signed QR codes  
- Rate limiting  
- Webhook validation  
- Logging, audit logs, and compliance  

**Use When:**  
Implementing user flows, API endpoints, device authentication, scanning logic, notifications, or admin tooling.

---

## **08_cicd_and_deployment.md**  
**What it is:**  
The full CI/CD and deployment pipeline architecture.

**Covers:**  
- Pipeline phases  
- Performance regression stages  
- Blue/green & canary deployments  
- Database migration safety rules  
- Queue backpressure handling  
- Telemetry-based auto-rollbacks  
- Release packaging  

**Use When:**  
Working on deployments, migrations, environment configuration, or cluster infrastructure.

---

## **09_scaling_and_resilience.md**  
**What it is:**  
The system-level scaling strategy and resilience guarantees.

**Covers:**  
- Horizontal scaling mechanisms  
- Redis clustering  
- Postgres replicas  
- Fault tolerance  
- Flash-sale architecture  
- Node failure handling  
- Real-time scaling  
- Multi-region readiness  

**Use When:**  
Designing heavily loaded features, optimizing performance, or verifying production-readiness of a slice.

---

# 3. How These Documents Work Together

### **Foundation**  
Defines the *platform architecture*.

### **Multi-Tenancy**  
Defines *isolation and access*.

### **Caching & Real-Time**  
Defines *speed and responsiveness*.

### **Vertical Slices**  
Defines *how code must be structured*.

### **Eventing Model**  
Defines *how information flows* through the system.

### **Jobs & Async**  
Defines *offloaded, eventual, or long-running work*.

### **Security & Auth**  
Defines *identity, permissions, and safety*.

### **CI/CD & Deployment**  
Defines *how updates go live safely*.

### **Scaling & Resilience**  
Defines *how the platform behaves under load and failure*.

Together, they represent the **complete architectural specification** of VoelgoedEvents.

---

# 4. How Developers & AI Agents Should Use This Folder

### Before creating any feature:
**Read:**  
`01_foundation.md`  
`04_vertical_slices.md`  
`02_multi_tenancy.md`

### Before writing any domain logic:
**Read:**  
`02_multi_tenancy.md`  
`03_caching_and_realtime.md`  
`05_eventing_model.md`

### Before implementing workflows:
**Read:**  
`05_eventing_model.md`  
`06_jobs_and_async.md`  
`07_security_and_auth.md`

### Before optimizing performance:
**Read:**  
`03_caching_and_realtime.md`  
`09_scaling_and_resilience.md`

### Before deployments or migrations:
**Read:**  
`08_cicd_and_deployment.md`  

---

# 5. Architectural Guardrails (Non-Negotiable Rules)

1. **No business logic in controllers or LiveViews**  
2. **All domain logic lives in Ash resources/domains**  
3. **All operations must be tenant-scoped**  
4. **Every feature is a vertical slice**  
5. **Redis + ETS must be used correctly depending on hot/warm/cold data**  
6. **All real-time flows must use PubSub**  
7. **No direct DB reads on high-throughput paths**  
8. **All async work goes through Oban**  
9. **All QR and device operations must be validated server-side**  
10. **Performance & caching rules override convenience**  

These guardrails ensure:

- Scalability  
- Safety  
- Correctness  
- Maintainability  
- Performance  

---

# 6. Relationship to Other Documentation Folders

This folder defines **architecture**, not implementations.

Related folders:

- `/docs/domain/` — Domain specifications & responsibilities  
- `/docs/workflows/` — End-to-end workflow descriptions  
- `/docs/platform_overview.md` — What the platform *is*  
- `/docs/project_overview.md` — How the repo *works*  
- `/docs/AGENTS.md` — How AI agents must behave  

Together they form a **complete documentation system**.

---

# 7. Summary

The `/docs/architecture/` folder is the **architectural backbone** of VoelgoedEvents.  
It defines how the platform:

- Is structured  
- Evolves  
- Scales  
- Performs  
- Stays resilient  
- Stays secure  
- Supports real-time operations  
- Maintains multi-tenant guarantees  
- Powers high-performance ticketing and scanning  

Every technical decision in the platform must align with the documents within this directory.

