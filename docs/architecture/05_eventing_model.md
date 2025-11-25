Eventing Model Architecture
===========================

**VoelgoedEvents PlatformDocument: /docs/architecture/05\_eventing\_model.md**

1\. Purpose of This Document
----------------------------

This document defines the **complete event-driven architecture** of the VoelgoedEvents platform.

It covers:

*   Domain events
    
*   PubSub channels & naming conventions
    
*   Real-time delivery guarantees
    
*   Redis ephemeral event propagation
    
*   Event ordering & deduplication
    
*   UI event handling (LiveView + SvelteKit)
    
*   Stream/queue interactions
    
*   How vertical slices consume & emit events
    
*   How events integrate with Ash resources
    
*   Durability rules and failure recovery
    

This is a **core architectural document** and must be strictly followed across all slices and domains.

2\. Why Event-Driven Architecture?
----------------------------------

VoelgoedEvents must support:

*   Real-time seat availability
    
*   Flash-sale performance
    
*   Check-in + scanning throughput
    
*   Live dashboards
    
*   Funnel tracking
    
*   Payment status propagation
    
*   Notification triggers
    
*   Webhook emission
    
*   Offline device sync
    

This requires a **push-based system**, not a polling one.

Events guarantee:

*   Fast UI updates
    
*   Consistent multi-node state
    
*   Reactive workflows
    
*   Lower DB load
    
*   High concurrency safety
    
*   Predictable slice interactions
    

3\. Categories of Events
------------------------

The platform defines **four layers** of events:

1.  **Domain Events** (Ash resource-level)
    
2.  **System Events** (PubSub)
    
3.  **Ephemeral Events** (Redis streams/counters)
    
4.  **Workflow Events** (Oban jobs + orchestrations)
    

Each layer has rules and responsibilities.

4\. Domain Events (Ash)
-----------------------

Domain events reflect **state changes to domain resources**.

**Examples:**

*   ticket.sold
    
*   ticket.redeemed
    
*   payment.authorized
    
*   payment.refunded
    
*   event.published
    
*   seat.hold\_created
    
*   seat.hold\_expired
    
*   scan.accepted
    
*   scan.rejected
    
*   coupon.applied
    

### 4.1 General Format

Domain events must contain:

Plaintext

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   event_type  organization_id  resource_type  resource_id  persisted_change  timestamp  metadata (optional)   `

### 4.2 Emission Rules

*   Emitted **after** successful Ash action commit
    
*   Never emitted on failed transaction
    
*   Ordered **per resource**, but not globally
    
*   Must include tenant context
    
*   Must be logged to telemetry
    

### 4.3 Consumers

*   PubSub event broadcasters
    
*   Slice orchestrators
    
*   Workflow triggers
    
*   Caching invalidators
    
*   Analytics collectors
    
*   Notification schedulers
    

5\. System Events (Phoenix PubSub)
----------------------------------

System events are emitted to **real-time subscribers**, including:

*   LiveViews
    
*   SvelteKit front-end
    
*   Scanner devices
    
*   Dashboard widgets
    
*   Admin interfaces
    
*   Background observers
    

System events are **not persisted**.If missed, the client reconnects and rehydrates from Redis/DB.

### 5.1 Naming Convention (Mandatory)

All PubSub topics must include {org\_id}:

YAML

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   events:org:{org_id}  events:event:{event_id}  ticketing:org:{org_id}  ticketing:event:{event_id}  ticketing:order:{order_id}  seating:event:{event_id}  scanning:org:{org_id}  scanning:session:{session_id}  analytics:event:{event_id}  analytics:org:{org_id}  notifications:org:{org_id}  audit:org:{org_id}  reporting:org:{org_id}   `

### 5.2 Real-Time Guarantees

*   **At least once delivery** within a node
    
*   **At most once delivery** to a UI client (UI dedupe required)
    
*   Delivery time target: **< 150ms** end-to-end
    

### 5.3 PubSub Event Payload

JSON

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   {    "event": "ticket.sold",    "org_id": "...",    "event_id": "...",    "data": {...},    "timestamp": ...  }   `

### 5.4 Subscriptions

**LiveViews:**

Elixir

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   Phoenix.PubSub.subscribe(MyApp.PubSub, "ticketing:event:#{event_id}")   `

**SvelteKit:**

*   WebSocket bridge
    
*   Server-side subscription proxies
    

**Devices:**

*   Scanner real-time channels
    
*   Device sync channel per org
    

6\. Ephemeral Events (Redis)
----------------------------

Ephemeral events are stored in Redis and consumed by:

*   Real-time dashboards
    
*   Funnel tracking pipelines
    
*   Rate limiters
    
*   Deduplication guards
    
*   Background jobs
    

Redis does not broadcast.It stores the current real-time operational state.

### 6.1 Structures Used

*   **Redis Streams** (analytics funnels, device logs)
    
*   **Redis ZSETs** (holds, expiration events)
    
*   **Redis LISTS** (webhook queues, notification queues)
    
*   **Redis BITMAPS** (seat availability)
    
*   **Redis HASHES** (GA inventory, pricing caches)
    
*   **Redis COUNTERS** (scan throughput, API rate limits)
    

### 6.2 Ephemeral Event Lifecycle

1.  Domain event triggers write to Redis structure
    
2.  Redis TTL or ZSET expiration manages lifecycle
    
3.  Workers consume events and produce domain/system events
    
4.  Redis auto-cleans expired shards
    

7\. Workflow Events (Oban Jobs)
-------------------------------

Workflow events represent async steps in multi-phase operations.

**Examples:**

*   Payment reconciliation
    
*   Hold expiration worker
    
*   Webhook retry job
    
*   Report generation
    
*   Email notification delivery
    
*   Large export pipeline
    

Workflow events are durable and persisted in Postgres.

### 7.1 Job Emission Rules

Jobs must be enqueued for:

*   All slow operations
    
*   All retryable operations
    
*   All operations requiring durability
    
*   All long-running tasks
    

### 7.2 Job Guarantees

*   At least once execution
    
*   Idempotency required
    
*   Tenant-scoped queue rules
    

### 7.3 Queue Naming

YAML

Plain textANTLR4BashCC#CSSCoffeeScriptCMakeDartDjangoDockerEJSErlangGitGoGraphQLGroovyHTMLJavaJavaScriptJSONJSXKotlinLaTeXLessLuaMakefileMarkdownMATLABMarkupObjective-CPerlPHPPowerShell.propertiesProtocol BuffersPythonRRubySass (Sass)Sass (Scss)SchemeSQLShellSwiftSVGTSXTypeScriptWebAssemblyYAMLXML`   queue:org:{org_id}:payments  queue:org:{org_id}:notifications  queue:org:{org_id}:scanning  queue:org:{org_id}:reporting  queue:org:{org_id}:integrations   `

8\. Event Flow Life-Cycle
-------------------------

A typical event may follow this flow:

### 8.1 Example: Ticket Purchased

1.  User finishes checkout
    
2.  Ash action Ticketing.issue\_ticket/1 triggers
    
3.  Domain event emitted: ticket.sold
    
4.  System event broadcast via PubSub: ticketing:event:{event\_id}
    
5.  Redis updated:
    
    *   Release holds
        
    *   Update availability bitmap
        
    *   Increment sold counters
        
6.  LiveView dashboard updates instantly
    
7.  Notification slice queues confirmation email
    
8.  Analytics slice logs funnel conversion
    
9.  Reporting slice will include this in tomorrow’s aggregates
    
10.  Oban worker fires PSP capture reconciliation
    

9\. Ordering, Idempotency & Deduplication
-----------------------------------------

Events must be resilient to:

*   Duplicate delivery
    
*   Out-of-order arrival
    
*   Partial failure
    
*   Node restarts
    
*   Network partition
    

### 9.1 Ordering Guarantees

*   Per-resource ordering is preserved
    
*   Cross-resource ordering is not guaranteed
    
*   UI must be resilient to reordering
    

### 9.2 Idempotency Requirements

Every event handler must be idempotent:

*   ticket.sold → safe to process twice
    
*   scan.accepted → must reject duplicates
    
*   payment.refund → check ledger before applying
    

### 9.3 Deduplication Rules

*   Redis keys for dedupe: integrations:incoming:dedupe:{id}
    
*   LiveView dedupe at UI layer
    
*   Stream processors dedupe by timestamp + hash
    
*   Domain events dedupe by primary key
    

10\. Event Versioning
---------------------

Events must be versioned only when schema changes.

**Naming example:**

*   ticket.sold.v1
    
*   ticket.sold.v2 # added seat\_meta
    

**Versioning rules:**

*   Only additive changes allowed in minor versions
    
*   Breaking changes require .vN bump
    
*   Consumers must handle version routing
    

11\. Error Handling & Failure Recovery
--------------------------------------

### 11.1 UI Missed Event Recovery

UI reconnects → loads from Redis → reconcilesEvents are not resent; instead, state is rehydrated.

### 11.2 Worker Recovery

Workers replay:

*   Redis streams
    
*   Oban retry queues
    
*   Hold expiration logic
    

### 11.3 Dead Letter Queue (DLQ)

queue:org:{org\_id}:dlq:{event\_type}

Used for:

*   Invalid webhook data
    
*   Unrecoverable notification failures
    
*   Events that cannot be mapped
    

12\. Event Security Model
-------------------------

Events MUST include:

*   organization\_id
    
*   actor\_user\_id (if applicable)
    
*   ip\_address for scanning/device events
    
*   timestamp
    

**Access control:**

*   No cross-tenant event visibility
    
*   System (admin) can subscribe globally
    
*   Devices subscribe only to authorized event scopes
    

**Sensitive data must be scrubbed:**

*   Card info
    
*   Personal addresses
    
*   PII outside what is needed for the event
    

13\. Observability & Telemetry for Events
-----------------------------------------

Every domain must expose telemetry:

*   Event emission count
    
*   Event handling duration
    
*   PubSub latency
    
*   Dropped messages
    
*   Redis stream depth
    
*   Job processing stats
    
*   API push latency
    
*   Event backlog
    

**Telemetry tags:**

*   organization\_id
    
*   event\_id
    
*   ticket\_id
    
*   domain
    
*   event\_type
    

14\. Summary
------------

The VoelgoedEvents event-driven architecture integrates:

*   **Ash Domain Events** (true resource changes)
    
*   **Phoenix PubSub** (real-time UI + device updates)
    
*   **Redis ephemeral state** (availability, holds, funnels, keys)
    
*   **Workflow events** (Oban durable jobs)
    

This unified eventing model ensures:

*   Reactive UI updates
    
*   Flash-sale scalability
    
*   Correct seat allocation
    
*   Robust device synchronization
    
*   Proper multi-tenant isolation
    
*   Fully testable, replayable workflows
    
*   Clear domain boundaries
    

All vertical slices must fully adopt this event-driven architecture.