Vertical Slice Architecture
===========================

VoelgoedEvents Platform

Document: /docs/architecture/04\_vertical\_slices.md

1\. Purpose of This Document
----------------------------

This document defines the **official Vertical Slice Architecture** for the VoelgoedEvents platform.

It ensures:

*   A consistent, scalable structure for all features
    
*   No “horizontal layer sprawl”
    
*   Clear boundaries between domains
    
*   Domain-driven Ash modeling for correctness
    
*   Real-time performance using ETS + Redis
    
*   UI consistency across Phoenix LiveView + SvelteKit
    
*   Explicit multi-tenant boundaries
    
*   Predictable developer and AI agent behavior
    

Vertical slices are the core of the VoelgoedEvents project architecture.

Every new feature must follow the slice rules described here.

2\. What Is a Vertical Slice?
-----------------------------

A **vertical slice** is a fully self-contained feature that includes:

*   UI (LiveView / SvelteKit View)
    
*   Events / Actions
    
*   Domain logic
    
*   Persistence
    
*   Caching
    
*   Real-time updates
    
*   Observability
    
*   Async jobs
    
*   API surface
    
*   Test suite
    
*   Documentation
    

A slice is **feature-oriented**, not layer-oriented.

**Examples:**

*   “Seat Selection”
    
*   “Checkout & Payment Finalization”
    
*   “Scan Ticket (Online/Offline)”
    
*   “Coupon Application & Dynamic Pricing”
    
*   “Create Event → Publish → Dashboard Metrics”
    
*   “Real-Time Attendance Throughput”
    
*   “Integration Webhooks (Stripe, PayFast)”
    

Each slice touches only the parts of the stack it needs.

Slices do not depend on each other horizontally.

3\. Why Vertical Slices?
------------------------

Legacy/horizontal architectures suffer from:

*   Massive coupling
    
*   Blob controllers
    
*   Business logic leaking everywhere
    
*   Ripple-effect bugs
    
*   Poor scaling
    
*   Difficult testability
    
*   Horrible AI agent performance
    

Vertical slices fix this by:

*   Encapsulating the entire workflow
    
*   Combining UI + domain + caching + async work
    
*   Ensuring correctness at the domain level
    
*   Making the system easy to scale out
    
*   Letting teams work in parallel
    
*   Enforcing consistency
    
*   Providing high-quality “units of completion”
    

4\. The Slice Template (Mandatory)
----------------------------------

Every slice must implement the following components:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   /lib/voelgoedevents    /slices      /{slice_name}        /ui                → LiveView, SvelteKit endpoints, components        /actions           → Thin Phoenix endpoints (if needed)        /domain            → Ash action orchestrators (delegates to domains)        /realtime          → PubSub listeners, streaming logic        /caching           → ETS adapters, Redis wrappers, warm caches        /jobs              → Oban workers        /services          → Integration adapters (PSP, SMS, email, etc.)        /tests             → Full slice test suite        /docs              → Local slice documentation   `

### Slice Naming Rules

*   Must use consistent snake\_case
    
*   Must represent a **user goal**, not a domain
    

**Examples:**

**❌ Bad✔ Good**ticketingseat\_selectionscanningticket\_validationpaymentcheckout\_and\_paymentanalyticsevent\_dashboard\_live

**Every slice must be deployable independently.**

5\. How Slices Use Domains
--------------------------

Slices **compose domain actions**, **never bypassing them**.

Example slice: _Seat Selection_

*   Reads availability from the **Ephemeral Domain**
    
*   Reads layout from **Seating Domain**
    
*   Creates holds in **Ticketing Domain**
    
*   Publishes events via **PubSub**
    
*   Reflects in UI via LiveView
    

Slices orchestrate; they **never contain business logic**.

6\. Rules for Domain Interaction
--------------------------------

Slices may:

*   Call **Ash actions**
    
*   Call **Ash domain interface modules**
    
*   Read/write to Redis via domain service modules
    
*   Emit PubSub events using domain topic structure
    
*   Queue Oban jobs for async work
    

Slices must **never**:

*   Reach directly into another slice’s UI components
    
*   Call other slices’ private modules
    
*   Query directly with Ecto
    
*   Bypass Ash conventions
    
*   Talk to Postgres without Ash
    
*   Mutate state stored in ETS without domain service abstractions
    
*   Access Redis directly without going through domain service modules
    

7\. UI Structure for a Slice
----------------------------

### 7.1 Phoenix LiveView

LiveView responsibilities:

*   Manage state transitions
    
*   Display real-time updates
    
*   Subscribe to PubSub
    
*   Use push\_event and stream\_insert
    

LiveViews must not:

*   Store domain logic
    
*   Mutate DB records
    
*   Perform pricing
    
*   Directly manipulate Redis/ETS
    
*   Handle multi-tenant permissions
    
*   Run heavy operations
    

### 7.2 SvelteKit Views (Optional)

When implementing a front-end SvelteKit app:

*   Only call REST APIs or GraphQL generated by slices
    
*   Must rely heavily on client-streamed updates from real-time endpoints
    
*   No business logic in the browser
    
*   Use IndexedDB for caching low-priority data
    

8\. Real-Time Layer Inside a Slice
----------------------------------

### Required behaviors:

*   Subscribe to tenant-scoped PubSub channels
    
*   React to domain events in under **100ms**
    
*   Push delta updates, not full render
    
*   Mirror state into ETS
    
*   Enforce atomic writes via Redis
    
*   Avoid heavy CPU operations on UI update cycle
    

Every slice must define at least:

*   /{slice}/realtime/listeners.ex
    
*   /{slice}/realtime/events.ex
    

9\. Caching Rules Within a Slice
--------------------------------

Slices must conform to the **global caching rules**:

*   Hot layer → ETS
    
*   Warm layer → Redis
    
*   Cold layer → Postgres
    

A slice must define:

1.  What state is cached
    
2.  Where it lives (ETS / Redis)
    
3.  What its TTL is
    
4.  What invalidation conditions apply
    
5.  What events cause updates
    

**Example (Seat Selection):**

**LayerStoragePurpose**ETSseat availability snapshotmicrosecond readRedis ZSETseat holdsauthoritative temporary ownershipRedis bitmapavailabilityhigh-volume atomic readsPostgressold seatsdurability

10\. Concurrency & Flash-Sale Safety
------------------------------------

Slices must enforce:

*   Optimistic locking
    
*   Atomic Redis operations
    
*   GenServer serialization for hot-path writes
    
*   Hold expiration via ZSET
    
*   Cache stampede protection
    
*   Micro-batching where necessary
    
*   No oversell under load
    

Each slice must include:

/{slice}/concurrency/safety\_rules.md

11\. Async Workflows Inside Slices
----------------------------------

Slices often spawn async jobs:

*   Webhook retry
    
*   Notification delivery
    
*   Report generation
    
*   Check-in device sync
    
*   Seat hold release
    
*   Payment reconciliation
    

Each slice must include:

/{slice}/jobs/{job\_name}\_worker.ex

Jobs must be:

*   Idempotent
    
*   Multi-tenant safe
    
*   Logged and observable
    
*   Restartable without corruption
    

12\. Observability & Logging per Slice
--------------------------------------

Each slice must expose:

*   telemetry events
    
*   logs
    
*   counters
    
*   success/failure metrics
    

No slice may:

*   Log sensitive payment info
    
*   Log user PII
    
*   Log decrypted keys
    
*   Write logs without tenant context
    

13\. How Slices Handle Multi-Tenancy
------------------------------------

Slices must:

*   Accept organization\_id explicitly
    
*   Filter all reads via Ash + tenancy context
    
*   Use tenant-scoped Redis keys
    
*   Subscribe to tenant-scoped PubSub topics
    
*   Use ETS only with {org\_id} in key
    

Slices must **never**:

*   Infer tenant from URL without validation
    
*   Share data between tenants
    
*   Subscribe to global topics
    

Refer also to: /docs/architecture/02\_multi\_tenancy.md

14\. Slice Lifecycle
--------------------

### 14.1 Slice Creation

A new slice begins with:

*   Domain orchestration file
    
*   LiveView or SvelteKit endpoint
    
*   Redis/ETS caching rules
    
*   PubSub subscriptions
    
*   Domain-level Ash actions
    
*   Tests
    
*   Documentation
    

### 14.2 Slice Completion

A slice is complete when:

*   It satisfies a full user workflow
    
*   It is testable end-to-end
    
*   It exposes telemetry
    
*   It has caching + real-time behavior
    
*   It respects tenant boundaries
    
*   It has no business logic in controllers or components
    

### 14.3 Slice Deployment

Slices deploy independently and non-destructively.

15\. Example Slice Walkthrough
------------------------------

### Example: _“Checkout & Payment Finalization Slice”_

This slice does:

*   Build cart → hold seats
    
*   Recalculate prices
    
*   Authorize payment
    
*   Capture payment
    
*   Complete ticket issuance
    
*   Publish events (ticket.sold, checkout.completed)
    
*   Trigger confirmation emails
    
*   Update analytics funnels
    
*   Update event dashboards
    
*   Release holds on failure
    

This slice touches:

*   Ticketing Domain
    
*   Payments & Ledger
    
*   Notifications
    
*   Analytics
    
*   Ephemeral Domain (Redis ZSET)
    
*   Jobs (async tasks)
    
*   Reporting Domain
    

But remains a **single coherent feature**.

16\. Summary
------------

Vertical slices are:

*   Self-contained
    
*   Feature-focused
    
*   Tenant-aware
    
*   Performance-optimized
    
*   Domain-driven
    
*   Easy to test
    
*   Easy to maintain
    
*   AI agent friendly
    
*   Safe under concurrency
    
*   Real-time reactive
    

Slices **compose** domain logic — they **never** own the logic themselves.

All future feature work MUST adhere to the slice architecture rules defined in this document.