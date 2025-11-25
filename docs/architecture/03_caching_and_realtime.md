Caching & Real-Time Architecture
================================

VoelgoedEvents Platform

Document: /docs/architecture/03\_caching\_and\_realtime.md

1\. Purpose of This Document
----------------------------

This document defines the **complete caching, state management, and real-time architecture** for the VoelgoedEvents platform.

It establishes:

*   Hot/Warm/Cold data tiers
    
*   ETS + Redis + Postgres interaction rules
    
*   Real-time event propagation (PubSub)
    
*   Seat availability correctness
    
*   Flash-sale throughput protections
    
*   LiveView + SvelteKit consistency guarantees
    
*   Caching rules for each domain
    

This is a **global platform rulebook** and applies to all vertical slices.

2\. Architectural Goals
-----------------------

Caching and real-time systems must:

*   Maintain **sub-100ms API latency**
    
*   Support **100k+ concurrent users**
    
*   Prevent **overselling** under flash-sale loads
    
*   Provide **instant UI updates** (LiveView)
    
*   Ensure **strong correctness** despite distributed state
    
*   Avoid **thundering herd + cache stampede**
    
*   Use **streaming**, not full reloads
    
*   Cache **responsibly**, never violating domain rules
    

These goals drive the design of the Hot / Warm / Cold tiering strategy.

3\. Hot / Warm / Cold Data Tier Model
-------------------------------------

VoelgoedEvents uses a strict **three-tier** model for performance.

### 3.1 Hot Layer (In-Memory: ETS, GenServers, Process State)

*   Ultra-low latency (microseconds)
    
*   Node-local ephemeral state
    
*   Holds the **state that MUST be microsecond-fast**:
    

#### Hot Layer Responsibilities

**Data TypeStorageTTLNotes**Seat availability snapshotETS bitmap/map< 5sUpdated via Redis or local eventsMembership & RBAC cachesETS30–120sHydrated via RedisActive checkout stateGenServer / ETS2–10 minRehydrated on-node restartPrice rule precomputationETS30–120sReduces expensive pricing logicRecently scanned ticketsETS< 30sPrevent duplicate-detection raceSeat hold lookupsETS< 60sMirrors Redis ZSET for super-fast reads

#### Hot Layer Constraints

*   Must always be **derivable** from Redis or Postgres.
    
*   Never considered the source of truth.
    
*   Must be **invalidated immediately** on writes.
    
*   Must **never** contain cross-tenant data.
    

### 3.2 Warm Layer (Redis)

Redis is the **primary distributed real-time state engine**, used for:

*   In-flight seat holds
    
*   Seat availability bitmaps
    
*   GA inventory counters
    
*   Funnel events
    
*   Rate limits & quotas
    
*   Scanning ticket flags
    
*   Job queues
    
*   Webhook dedupe
    
*   Report generation queues
    

Redis is the **truth** for ephemeral state.

#### Redis Responsibilities

**Redis StructurePurposeExample**ZSETSeat holds, expiry windowsticketing:holds:org:{org\_id}:event:{event\_id}BitmapSeat availabilityseating:availability:{event\_id}HashGA counters, pricing, settingsticketing:inventory:ga:{ticket\_type\_id}CounterRate limits, quotasapi:rate:{org\_id}:{key\_id}:{minute}ListNotification queues, webhook queuesnotifications:queue:{org\_id}StreamFunnel tracking, event logsanalytics:funnel:{event\_id}

#### Redis Constraints

*   Every key **must** include {org\_id}
    
*   Must support **atomic operations**
    
*   Expiration must be **explicit**
    
*   All cached data must be rebuildable from Postgres
    

### 3.3 Cold Layer (Postgres)

Postgres is the **durable, canonical store**.

Used for:

*   Domain resource persistence
    
*   Ledger correctness
    
*   Audit logging (immutable)
    
*   Historical reports
    
*   Materialized views
    

Cold layer data is:

*   100% authoritative
    
*   Indexed for per-org queries
    
*   Not suitable for high-concurrency reads
    
*   Accessed only when Redis/ETS misses
    

4\. Real-Time Architecture
--------------------------

Real-time features depend on:

*   Phoenix PubSub
    
*   Phoenix Presence (optional)
    
*   LiveView push updates
    
*   Redis state mirroring
    
*   High-frequency event broadcasts
    

### Core Real-Time Principles

1.  **No polling anywhere**
    
2.  LiveView uses **push\_patch** and **push\_event**
    
3.  SvelteKit front-end uses **EventSource/WebSockets**
    
4.  PubSub topics must include {org\_id}
    
5.  Caches must update **before** UI notifications
    
6.  Availability changes must propagate in **< 150ms**
    

5\. Real-Time Event Channels
----------------------------

Every domain defines PubSub topics, all tenant-scoped:

YAML

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   events:org:{org_id}  ticketing:event:{event_id}  seating:event:{event_id}  scanning:session:{session_id}  analytics:event:{event_id}  notifications:org:{org_id}  audit:org:{org_id}  reporting:org:{org_id}   `

### Rules

*   No cross-tenant broadcasts
    
*   Topics must be **stable** and **versioned** only when schema changes
    
*   LiveViews **subscribe once** on mount
    
*   SvelteKit can subscribe via WebSocket bridges
    

6\. Seat Availability & Oversell Protection
-------------------------------------------

Seat availability is the most critical real-time element.

### 6.1 Seat Holds (ZSET)

Redis ZSET stores:

Markdown

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   ( seat_id, expires_at_timestamp )   `

Used by:

*   Checkout
    
*   Auto-release worker
    
*   Seat selection UI
    

### 6.2 Availability Bitmap

A Redis bitmap (SETBIT) stores seat availability:

YAML

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   0 = free  1 = locked/held or sold   `

Benefits:

*   O(1) seat lookup
    
*   Atomic updates
    
*   Efficient for large venues
    

### 6.3 Invalidation Rules

*   Availability updates → write-through to Redis, mirrored into ETS
    
*   Hold expiration → background Oban worker removes expired holds
    
*   Checkout success → mark seat permanently sold (via Postgres transaction)
    

7\. GA Inventory Model
----------------------

GA inventory uses Redis counters + ETS mirrors:

*   available
    
*   sold
    
*   held
    

Counters must be atomic to prevent oversell.

DB-level optimistic locking verifies correctness before final sale.

8\. Notification, Webhook & Job Queues
--------------------------------------

All queues are stored in Redis:

*   Notification delivery queue
    
*   Outgoing webhook queue
    
*   Report generation queue
    
*   Offline scanning synchronization queue
    

Workers pull from Redis → load DB → perform action → ack/delete.

9\. Rate Limiting & API Quotas
------------------------------

Rate limits must use Redis counters:

YAML

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   api:rate:{org_id}:{key_id}:{minute}   `

Requirements:

*   Atomic INCR + TTL
    
*   Throttle high-volume endpoints
    
*   Protect scanning endpoints during spikes
    

10\. LiveView & SvelteKit Real-Time Integration
-----------------------------------------------

### LiveView

*   Subscribes to PubSub topics
    
*   Uses push\_event for UI deltas
    
*   Never reloads full layout
    
*   Reads from ETS when rendering
    

### SvelteKit (optional real-time front-end)

*   Uses EventSource or WebSocket bridge
    
*   Reads from REST endpoints that are backed by ETS/Redis
    
*   Receives incremental UI updates
    

### Shared Rules

*   UI must never directly call Postgres
    
*   All UI reads must go through domain actions → caching layer
    
*   Real-time streams serve **deltas**, not full datasets
    

11\. Thundering Herd + Cache Stampede Protection
------------------------------------------------

To prevent overload:

*   ETS always used first
    
*   Redis only hit when ETS misses
    
*   Writes use **write-through** semantics
    
*   Long TTLs with jitter
    
*   Request coalescing:
    
    *   First request regenerates cache
        
    *   Others await same result
        
*   Oban jobs rebuild cold caches in background
    

12\. Multi-Tenant Cache Encoding Rules
--------------------------------------

Every Redis + ETS key must embed:

YAML

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   {org_id}   `

Example patterns:

Markdown

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   ticketing:holds:org:{org_id}:event:{event_id}  seating:availability:org:{org_id}:event:{event_id}  notifications:queue:org:{org_id}  scan:org:{org_id}:ticket:{ticket_id}  api:rate:org:{org_id}:{key_id}:{minute}   `

Cross-tenant mixing is strictly forbidden.

13\. Cache Invalidation Strategy
--------------------------------

Critical principle:

> **Invalidation must be intentional and predictable — not “best effort.”**

### On write events:

*   Destroy ETS entries
    
*   Update Redis atomic structures
    
*   Publish domain event for UI updates
    
*   Trigger background rebuild if needed
    

### On seat selection:

*   Update hold ZSET
    
*   Update availability bitmap
    
*   Mirror into ETS
    
*   Trigger PubSub event
    

### On refund or cancellation:

*   Rebuild GA inventory counters
    
*   Update availability structures
    
*   Trigger PubSub refresh
    

14\. Recovery & Node Restart Behavior
-------------------------------------

### When a node restarts:

*   ETS is empty
    
*   Redis is intact
    
*   Postgres is intact
    

Nodes must:

1.  Rehydrate ETS from Redis
    
2.  Subscribe to correct PubSub channels
    
3.  Validate seat availability snapshots
    
4.  Restore active checkout states (Redis → ETS)
    
5.  Resume scheduled Oban jobs
    

15\. Observability
------------------

The system must track:

*   Redis latency
    
*   ETS hit/miss ratios
    
*   PubSub message propagation time
    
*   Seat hold expiration accuracy
    
*   Duplicate scan protection stats
    
*   Cache stampede counts
    
*   Checkout p99 latency
    
*   Worker queue depth
    

Telemetry must include:

*   organization\_id
    
*   event\_id
    
*   ticket\_type\_id
    
*   job\_type
    

16\. Summary
------------

The VoelgoedEvents caching & real-time architecture is built on:

*   **Hot layer:** ETS / GenServers for microsecond access
    
*   **Warm layer:** Redis for distributed consistency
    
*   **Cold layer:** Postgres for persistence
    
*   **PubSub:** event-driven UI updates
    
*   **Atomic structures:** ZSETs, bitmaps, counters
    
*   **Strong invariants:** no oversell, no stampede, no cross-tenant leakage
    
*   **Real-time readiness:** LiveView + SvelteKit both supported
    

All vertical slices and domain implementations **must follow these caching and real-time rules** to ensure scale, correctness, and performance.