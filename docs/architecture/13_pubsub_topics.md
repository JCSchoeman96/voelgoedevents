# docs/architecture/13_pubsub_topics.md

**VoelgoedEvents: Phoenix PubSub Real-Time Communication Architecture**

*Last Updated: 2025-12-07 (Rev 2: Production-Ready Upgrades)*  
*Status: Authoritative Specification*  
*Audience: Backend architects, LiveView developers, scanner device teams*

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [PubSub Naming Standards](#1-pubsub-naming-standards)
3. [Topic Registry](#2-topic-registry)
4. [Implementation Patterns (Ash Framework)](#3-implementation-patterns-ash-framework)
5. [Security & Authorization](#4-security--authorization)
6. [Payload Specifications](#5-payload-specifications)
7. [Operational Concerns](#6-operational-concerns)
8. [Future Extensions (Phase 3+)](#7-future-extensions-phase-3)
9. [Quick Reference](#appendix-quick-reference)

---

## Executive Summary

VoelgoedEvents uses a **dual-tier PubSub architecture** to prevent fan-out DDoS during Phase 3 scaling:

- **Tier 1 (Org-Scoped):** Low-volume admin operations (Accounts, Finance, Events)
  - Pattern: `org:{org_id}:{domain}:{entity}:{action}`
  - Single broadcast to org-wide subscribers

- **Tier 2 (Event-Scoped):** High-volume real-time operations (Seating, Scanning, Ticketing)
  - Pattern: `org:{org_id}:event:{event_id}:{domain}:{entity}:{action}`
  - Users subscribe to ONE event only; prevents cross-event noise
  - **Critical for Phase 3:** 5 concurrent events × 100 seat holds/sec = each user sees only their event's 20 holds

**Key Additions (Rev 2):**
1. Tier 1 vs. Tier 2 decision framework with critical Phase 3 justification
2. `VoelgoedEvents.Topics` module for type-safe topic generation (eliminates string interpolation bugs)
3. Presence Registry for Phase 3+ social proof features ("5 people viewing this seat")
4. Updated Topic Registry with event-scoped topics for all high-volume domains
5. Cross-event isolation tests and verification patterns

---

## 1. PubSub Naming Standards

### 1.1 Canonical Topic Patterns

To balance standard hierarchy with performance, VoelgoedEvents uses **two tiers of topics**:

#### Tier 1: Organization-Scoped (Low Volume / Admin)

**Usage:** Accounts, Finance, Config changes, non-time-sensitive operations.

```
org:{org_id}:{domain}:{entity}:{action}
```

**Examples:**
```
org:550e8400-e29b-41d4-a716-446655440000:accounts:user:deactivated
org:550e8400-e29b-41d4-a716-446655440000:payments:transaction:authorized
org:550e8400-e29b-41d4-a716-446655440000:events:event:published
```

**Characteristics:**
- Broadcast to entire organization
- Frequency: < 10/sec (typically 1-5/sec)
- Subscribers: Admin dashboards, finance systems, background jobs
- No event-level filtering needed

#### Tier 2: Event-Scoped (High Volume / Real-Time)

**Usage:** Seating, Scanning, Ticketing status updates — domains where multiple concurrent events exist and clients must NOT receive cross-event noise.

```
org:{org_id}:event:{event_id}:{domain}:{entity}:{action}
```

**Examples:**
```
org:550e8400-e29b-41d4-a716-446655440000:event:abc-event-1:seating:seat:held
org:550e8400-e29b-41d4-a716-446655440000:event:abc-event-1:scanning:scan:admitted
org:550e8400-e29b-41d4-a716-446655440000:event:abc-event-1:ticketing:ticket:issued
```

**Characteristics:**
- Broadcast only to subscribers of ONE event
- Frequency: 10-1000/sec (scale depends on concurrent users)
- Subscribers: Event-specific LiveViews, scanner devices, occupancy dashboards
- Event-level filtering REQUIRED; prevents cross-event noise

### 1.2 The Phase 3 Fan-Out Problem & Solution

**Scenario:** Organization "BigConcerts" runs 5 concurrent events with overlapping sales windows.

#### ❌ OLD PATTERN (Tier 1 for Everything)

```
User A viewing Event 1 subscribes to: org:BigConcerts:seating:*
```

**Result at Peak Load:**
```
Total seat holds/sec across all events: 500 (100 per event)
User A receives: 500 messages/sec
User A's client buffer: Overflows
User A's browser: Unresponsive
```

**Why it fails:**
- All users get all events' updates
- No filtering at PubSub layer (client-side filtering insufficient at scale)
- Message volume = O(n × m) where n = users, m = events

#### ✅ NEW PATTERN (Tier 2 for High-Volume)

```
User A viewing Event 1 subscribes to: org:BigConcerts:event:event-1:seating:*
```

**Result at Same Peak Load:**
```
Total seat holds/sec across all events: 500 (100 per event)
User A receives: 100 messages/sec (event 1 only)
User A's client buffer: Comfortable
User A's browser: Responsive
```

**Why it works:**
- Each user only gets their event's updates
- PubSub filters at topic level (hardware-efficient)
- Message volume = O(n) where n = event-specific users

**Mathematics:**
- 5 events, 100 users/event = 500 total users
- Each user views 1 event
- Seating broadcasts: 500/sec total, but spread across 5 topics
- User A sees: 100/sec (1 topic) instead of 500/sec (all topics)
- **5x reduction in client message load**

### 1.3 Decision Tree: Which Tier?

```
Is this domain time-sensitive with high frequency (>10/sec)?
├─ YES: Seating, Scanning, Ticketing (real-time, user-facing)
│  └─ Is the operation scoped to ONE event?
│     ├─ YES (single event operation)
│     │  └─ Use Tier 2: org:{org_id}:event:{event_id}:{domain}:{entity}:{action}
│     └─ NO (org-level operation, rare for high-volume)
│        └─ Architect to emit Tier 2 instead
│
└─ NO: Accounts, Events, Payments, Notifications (admin/config)
   └─ Use Tier 1: org:{org_id}:{domain}:{entity}:{action}
```

### 1.4 Field Definitions

| Field | Type | Description | Constraint | Tier |
|-------|------|-------------|-----------|------|
| `org_id` | UUID | Organization tenant identifier | REQUIRED, no defaults, no wildcards in publish | Both |
| `event_id` | UUID | Event identifier (scoping high-volume domains) | REQUIRED for Tier 2; MUST be interpolated into topic at publish time | Tier 2 only |
| `domain` | String | Ash domain name (lowercase) | seating, ticketing, scanning, accounts, events, payments, notifications, etc. | Both |
| `entity` | String | Resource name (lowercase) | seat, seathold, ticket, scan, event, checkout, user, etc. | Both |
| `action` | String | State transition or event (lowercase) | held, released, sold, scanned, created, updated, deleted, admitted, denied, etc. | Both |

### 1.5 Multi-Level Subscription (Wildcard Rules)

Phoenix PubSub supports pattern-based subscriptions using string matching.

#### Tier 1 Examples

```elixir
# Subscribe to all user events for an org
Phoenix.PubSub.subscribe(
  VoelgoedeventsWeb.Endpoint,
  "org:#{org_id}:accounts:user:*"
)

# Subscribe to all domain events (Finance)
Phoenix.PubSub.subscribe(
  VoelgoedeventsWeb.Endpoint,
  "org:#{org_id}:payments:*"
)
```

#### Tier 2 Examples (Event-Scoped)

```elixir
# ✅ RECOMMENDED: Subscribe to all seat events for ONE event
Phoenix.PubSub.subscribe(
  VoelgoedeventsWeb.Endpoint,
  "org:#{org_id}:event:#{event_id}:seating:*"
)

# ⚠️ CAUTION: Subscribe to all events (high volume, use only for dashboards)
Phoenix.PubSub.subscribe(
  VoelgoedeventsWeb.Endpoint,
  "org:#{org_id}:event:*:seating:*"
)
# Only if you need cross-event analytics dashboard
```

### 1.6 Naming Conventions & Anti-Patterns

**✅ MUST:**
- Use lowercase domain, entity, and action names
- Separate components with colons (`:`)
- Include `org_id` as first component for every topic
- **For Tier 2 domains, include `event_id` immediately after `org_id`**
- Use past-tense verbs for actions (`held`, `released`, `sold`, `admitted`)
- Use plural for aggregate topics (`occupancy`, `capacity`, `stats`)

**❌ MUST NOT:**
- Use CamelCase, snake_case, or hyphens in topic names
- Omit `org_id` from topic pattern (critical for multi-tenancy)
- Use Tier 1 pattern for Tier 2 domains (will cause cross-event fan-out at scale)
- Publish user-controlled data in topic names (SQL injection risk)
- Create ad-hoc topics without adding to Topic Registry (Section 2)
- Use positive verbs like `will`, `should` for actions (use declarative state changes)

**Example Anti-Patterns:**

```elixir
# ❌ BAD: Missing org_id (cross-tenant leak risk)
"seating:seat:held"

# ❌ BAD: Tier 1 pattern for high-volume domain (Phase 3 DDoS)
"org:#{org_id}:seating:seat:held"
# Correct: "org:#{org_id}:event:#{event_id}:seating:seat:held"

# ❌ BAD: Missing event_id for Tier 2 (cross-event noise)
"org:#{org_id}:scanning:scan:admitted"
# Correct: "org:#{org_id}:event:#{event_id}:scanning:scan:admitted"

# ❌ BAD: CamelCase (breaks pattern matching)
"org:#{org_id}:event:#{event_id}:Seating:Seat:Held"

# ❌ BAD: User input in topic (injection risk)
"org:#{org_id}:event:#{user_provided_event_id}:seating:..."

# ❌ BAD: Overly specific keys (not topics, these belong in payloads)
"org:#{org_id}:event:#{event_id}:seating:seat:#{seat_id}:held"
# Correct: Topic is above, seat_id in payload
```

### 1.7 Why This Dual Pattern?

**Security:** `org_id` prefix ensures subscribers can only access their tenant's topics.  
**Scalability (Tier 2):** `event_id` prevents cross-event noise; clients only see relevant updates. **Essential for Phase 3 interactive seating (5000+ concurrent users).**  
**Discoverability:** Hierarchical structure is self-documenting.  
**Pattern Matching:** Phoenix PubSub's wildcard support enables efficient filtering.  
**Compliance:** Clear audit trail; every broadcast logs organization and event context.

---

## 2. Topic Registry

The **Topic Registry** is the Single Source of Truth for all PubSub topics in VoelgoedEvents. Every new topic MUST be added here before being used in code.

### 2.1 How to Read This Table

| Column | Meaning |
|--------|---------|
| **Topic Pattern** | Exact topic name; follow Section 1.1 (Tier 1 or Tier 2) |
| **Tier** | Tier 1 (Org-Scoped) or Tier 2 (Event-Scoped) |
| **Publisher** | Ash Domain/Action that broadcasts this topic |
| **Subscribers** | LiveView, scanner, external systems that consume this topic |
| **Payload** | JSON structure emitted by `Phoenix.PubSub.broadcast/3` |
| **Frequency** | Expected broadcast rate: high (>1/sec), medium (1/min–1/sec), low (<1/min) |
| **Latency SLA** | Acceptable propagation delay; impacts subscriber UX/decisions |

### 2.2 Registry by Domain

#### **SEATING Domain** (Tier 2: Event-Scoped)

| Topic Pattern | Tier | Publisher | Subscribers | Payload | Frequency | Latency SLA | Notes |
|---|---|---|---|---|---|---|---|
| `org:{org_id}:event:{event_id}:seating:seat:held` | 2 | `Seating.ReserveSeat` action | Occupancy dashboard, LiveView maps, scanner sync | `{event: "seat_held", seat_id: UUID, block_id: UUID, seat_number: String, user_id: UUID, held_until: DateTime, total_held_in_event: Integer}` | Medium (high during peak sales) | <1s | Fires when user reserves a seat (5-min hold). Event-scoped prevents cross-event noise during concurrent sales. |
| `org:{org_id}:event:{event_id}:seating:seat:released` | 2 | `Seating.ReleaseSeat` action (TTL, user cancel, payment fail) | Occupancy dashboard, LiveView maps, other waiting users | `{event: "seat_released", seat_id: UUID, block_id: UUID, seat_number: String, reason: "ttl_expired"\|"user_cancelled"\|"payment_failed", released_at: DateTime, total_available_in_event: Integer}` | Medium (high during peak sales) | <500ms | Fires when hold expires, user cancels, or payment fails. Event-scoped reduces client filter overhead. |
| `org:{org_id}:event:{event_id}:seating:seat:sold` | 2 | `Ticketing.CompleteCheckout` action | Occupancy dashboard, analytics, event capacity monitor | `{event: "seat_sold", seat_id: UUID, block_id: UUID, seat_number: String, event_id: UUID, ticket_id: UUID, user_id: UUID, price_cents: Integer, sold_at: DateTime, total_sold_in_event: Integer, percent_capacity_used: Float}` | Medium (high during sales peak) | <2s | Fires when ticket issued. Event-scoped ensures only relevant users update seat maps. Includes pricing for analytics. |
| `org:{org_id}:event:{event_id}:seating:occupancy:updated` | 2 | `Seating.CalculateOccupancy` (async, scheduled) | Storefront occupancy gauge, admin dashboard, analytics | `{event: "occupancy_updated", event_id: UUID, total_capacity: Integer, total_sold: Integer, total_held: Integer, total_available: Integer, percent_sold: Float, percent_held: Float, percent_available: Float, timestamp: DateTime}` | Low (updates every 5–10s via background job) | <5s | Aggregated occupancy snapshot for a specific event. Scheduled job prevents excessive broadcasts. |
| `org:{org_id}:event:{event_id}:seating:block:capacity_critical` | 2 | `Seating.MonitorCapacity` (async alert) | Admin dashboard, venue staff alerts | `{event: "capacity_critical", event_id: UUID, block_id: UUID, block_name: String, threshold_percent: Integer, current_percent: Integer, seats_remaining: Integer, alert_at: DateTime}` | Low (only when threshold breached) | <10s | Fires once when occupancy crosses alert threshold (e.g., 90%). Event-scoped alerts only relevant staff. |

#### **TICKETING Domain** (Tier 2: Event-Scoped)

| Topic Pattern | Tier | Publisher | Subscribers | Payload | Frequency | Latency SLA | Notes |
|---|---|---|---|---|---|---|---|
| `org:{org_id}:event:{event_id}:ticketing:ticket:issued` | 2 | `Ticketing.CompleteCheckout` action | Confirmation email worker, QR generation job, analytics | `{event: "ticket_issued", ticket_id: UUID, ticket_code: String, user_id: UUID, event_id: UUID, seat_id: UUID, checkout_id: UUID, order_number: String, price_cents: Integer, issued_at: DateTime}` | Medium (during sales peak) | <1s | Fires immediately after Checkout completes. Event-scoped prevents email jobs processing unrelated events. **Payload is minimal to reduce Redis footprint** (see Section 5). |
| `org:{org_id}:event:{event_id}:ticketing:ticket:voided` | 2 | `Ticketing.VoidTicket` action (refund, admin cancel) | Admin dashboard, accounting system, customer notifications | `{event: "ticket_voided", ticket_id: UUID, ticket_code: String, event_id: UUID, user_id: UUID, reason: "refund"\|"admin_cancel"\|"duplicate", refund_amount_cents: Integer, voided_at: DateTime}` | Low | <2s | Fired on manual void or refund. Event-scoped ensures ledger entries routed to correct event. |
| `org:{org_id}:event:{event_id}:ticketing:checkout:started` | 2 | `Ticketing.StartCheckout` action | Analytics funnel, admin session monitor | `{event: "checkout_started", checkout_id: UUID, user_id: UUID, event_id: UUID, seat_count: Integer, subtotal_cents: Integer, started_at: DateTime, expires_at: DateTime}` | Medium (during sales peak) | <1s | Fires when checkout session created (15-min timeout). Event-scoped tracks funnel per event. |
| `org:{org_id}:event:{event_id}:ticketing:checkout:completed` | 2 | `Ticketing.CompleteCheckout` action | Analytics conversion funnel, revenue dashboard, notifications | `{event: "checkout_completed", checkout_id: UUID, user_id: UUID, event_id: UUID, seat_count: Integer, total_cents: Integer, payment_reference: String, completed_at: DateTime}` | Medium (during sales peak) | <1s | Fires after payment confirmed and tickets issued. Event-scoped revenue snapshot. |
| `org:{org_id}:event:{event_id}:ticketing:checkout:abandoned` | 2 | `Oban.Workers.AbandonCheckout` job | Analytics churn analysis, marketing re-engagement | `{event: "checkout_abandoned", checkout_id: UUID, user_id: UUID, event_id: UUID, seat_count: Integer, subtotal_cents: Integer, reason: "timeout"\|"user_cancelled", abandoned_at: DateTime}` | Low | <5s | Fires 15 min after checkout started if not completed. Event-scoped tracks abandonment per event. |

#### **SCANNING Domain** (Tier 2: Event-Scoped for Tickets, Tier 1: Device Management)

| Topic Pattern | Tier | Publisher | Subscribers | Payload | Frequency | Latency SLA | Notes |
|---|---|---|---|---|---|---|---|
| `org:{org_id}:event:{event_id}:scanning:scan:admitted` | 2 | `Scanning.ProcessScan` action (admission path) | Scanner device UI, gate occupancy dashboard, admin panel | `{event: "ticket_admitted", ticket_code: String, ticket_id: UUID, seat_id: UUID, block_name: String, row: String, seat_number: String, gate_id: UUID, gate_name: String, gate_occupancy: Integer, gate_capacity: Integer, scanned_at: DateTime, device_id: UUID}` | High (100+/min at peak) | <200ms | Broadcast to event-scoped topic so scanner tablet sees immediate green checkmark. Event-scoped prevents cross-event gate confusion. **Byte-efficient payload** (Section 5). |
| `org:{org_id}:event:{event_id}:scanning:scan:denied` | 2 | `Scanning.ProcessScan` action (denial path) | Scanner device UI, gate dashboard, fraud alerts | `{event: "ticket_denied", ticket_code: String, ticket_id: UUID, reason: "not_found"\|"already_used"\|"wrong_event"\|"event_inactive"\|"gate_full", gate_id: UUID, gate_name: String, scanned_at: DateTime, device_id: UUID}` | High (100+/min) | <200ms | Broadcast to event-scoped topic. Reason field drives scanner UI display (red X + message). |
| `org:{org_id}:event:{event_id}:scanning:occupancy:updated` | 2 | `Scanning.ProcessScan` (after every scan, async aggregation) | Admin gate dashboard, gate occupancy gauge, overflow alerts | `{event: "gate_occupancy_updated", event_id: UUID, gate_id: UUID, gate_name: String, current_occupancy: Integer, gate_capacity: Integer, percent_full: Float, gates: [{gate_id, occupancy, capacity, percent}], timestamp: DateTime}` | High (updates after every scan) | <500ms | Broadcast to event-level topic. Aggregated occupancy across all gates for ONE event. Enables "Gate A: 342/500 (68%)" live dashboards. |
| `org:{org_id}:event:{event_id}:scanning:fraud:alert` | 2 | `Scanning.DetectFraud` action | Security team dashboard, automated lockdown | `{event: "fraud_alert", alert_type: "impossible_travel"\|"duplicate_spam"\|"high_velocity", ticket_id: UUID, ticket_code: String, gate_id: UUID, device_id: UUID, severity: "info"\|"warning"\|"critical", details: {...}, detected_at: DateTime}` | Low | <1s | Fires when suspicious pattern detected. Event-scoped ensures fraud alerts routed to correct event security team. |
| `org:{org_id}:scanning:device:offline` | 1 | `Scanning.MonitorDeviceHeartbeat` (background job) | Admin device status panel, IT alerts | `{event: "device_offline", device_id: UUID, device_name: String, last_heartbeat: DateTime, offline_duration_seconds: Integer, gate_id: UUID}` | Low (only on state change) | <5s | Fires when device's last heartbeat > 5 min. Alerts IT to restart/troubleshoot scanner. Org-scoped (device status is org-level). |
| `org:{org_id}:scanning:device:online` | 1 | `Scanning.ScanDevice.Heartbeat` action | Admin status panel, operational dashboards | `{event: "device_online", device_id: UUID, device_name: String, online_at: DateTime, battery_percent: Integer, network_signal_strength: Integer, gate_id: UUID}` | Low (updates every 30 sec per device) | <2s | Sent on each device heartbeat. Includes device health (battery, signal) for IT monitoring. Org-scoped. |

#### **ACCOUNTS Domain** (Tier 1: Org-Scoped)

| Topic Pattern | Tier | Publisher | Subscribers | Payload | Frequency | Latency SLA | Notes |
|---|---|---|---|---|---|---|---|
| `org:{org_id}:accounts:user:created` | 1 | `Accounts.CreateUser` action | CRM integration, welcome email job, analytics | `{event: "user_created", user_id: UUID, email: String, name: String, role: "customer"\|"staff"\|"admin", created_at: DateTime}` | Low | <1s | User registration. Minimal PII; email and name only. Triggers welcome workflow. Org-scoped. |
| `org:{org_id}:accounts:user:deactivated` | 1 | `Accounts.DeactivateUser` action (admin action) | **Kill all active sessions**, force logout, auth revocation | `{event: "user_deactivated", user_id: UUID, reason: "banned"\|"suspended"\|"voluntary", deactivated_at: DateTime}` | Low (rare, admin-initiated) | <500ms | **CRITICAL SECURITY**: When fired, all LiveView sockets for this user MUST disconnect immediately (see Section 4). This topic has NO opt-out; all auth systems subscribe. Org-scoped. |
| `org:{org_id}:accounts:user:role_changed` | 1 | `Accounts.UpdateUserRole` action | RBAC enforcement, permission refresh | `{event: "user_role_changed", user_id: UUID, old_role: String, new_role: String, changed_at: DateTime, changed_by: UUID}` | Low | <1s | Admin changes user role (customer → staff). LiveViews re-check permissions on next interaction. Org-scoped. |
| `org:{org_id}:accounts:organization:limits_exceeded` | 1 | `Accounts.MonitorOrgLimits` (scheduled job) | Billing alerts, usage dashboards | `{event: "org_limits_exceeded", organization_id: UUID, limit_type: "users"\|"events"\|"api_calls", current_usage: Integer, limit: Integer, exceeded_at: DateTime}` | Low | <10s | Fires when org hits usage limit (e.g., 100 users on 100-user plan). Triggers billing notification. Org-scoped. |

#### **EVENTS Domain** (Tier 1: Org-Scoped)

| Topic Pattern | Tier | Publisher | Subscribers | Payload | Frequency | Latency SLA | Notes |
|---|---|---|---|---|---|---|---|
| `org:{org_id}:events:event:published` | 1 | `Events.PublishEvent` action | Storefront indexing, search engines, integrations | `{event: "event_published", event_id: UUID, event_name: String, start_date: DateTime, end_date: DateTime, capacity: Integer, published_at: DateTime}` | Low | <2s | Event goes live. Triggers indexing, public visibility, sales enable. Org-scoped (event creation is org-level). |
| `org:{org_id}:events:event:cancelled` | 1 | `Events.CancelEvent` action | Customer notifications, refund jobs, occupancy reset | `{event: "event_cancelled", event_id: UUID, event_name: String, reason: String, cancelled_at: DateTime, ticket_count_affected: Integer}` | Low | <1s | Event is cancelled. Triggers automatic refund job (Oban). Notifies all ticket holders. Org-scoped. |
| `org:{org_id}:events:event:status_changed` | 1 | `Events.UpdateEventStatus` action | Analytics, dashboards, integrations | `{event: "event_status_changed", event_id: UUID, old_status: String, new_status: String, changed_at: DateTime}` | Low | <1s | Event state transition (draft → published → live → ended). Enables business logic. Org-scoped. |

#### **PAYMENTS Domain** (Tier 1: Org-Scoped)

| Topic Pattern | Tier | Publisher | Subscribers | Payload | Frequency | Latency SLA | Notes |
|---|---|---|---|---|---|---|---|
| `org:{org_id}:payments:transaction:authorized` | 1 | `Payments.AuthorizePayment` action (webhook handler) | Checkout completion, order fulfillment | `{event: "transaction_authorized", payment_reference: String, checkout_id: UUID, amount_cents: Integer, currency: String, method: "stripe"\|"paypal", authorized_at: DateTime}` | Medium (during sales peak) | <2s | Payment provider confirmed charge. Unblocks ticket issuance. Org-scoped (payment is org-level financial event). |
| `org:{org_id}:payments:transaction:failed` | 1 | `Payments.AuthorizePayment` action (webhook, failure path) | Retry handler, customer notification, seat release | `{event: "transaction_failed", payment_reference: String, checkout_id: UUID, amount_cents: Integer, reason: "insufficient_funds"\|"declined"\|"timeout", failed_at: DateTime}` | Low | <1s | Payment denied. Triggers `ReleaseSeat` to free holds. Customer notified to retry. Org-scoped. |
| `org:{org_id}:payments:ledger:entry_recorded` | 1 | `Payments.RecordLedgerEntry` action | Accounting reconciliation, audit trails | `{event: "ledger_entry_recorded", entry_id: UUID, journal_type: "revenue"\|"refund"\|"fee"\|"tax", amount_cents: Integer, reference_type: String, reference_id: UUID, recorded_at: DateTime}` | Medium | <500ms | Double-entry accounting logged. Non-blocking; logged for audit. Org-scoped. |

#### **NOTIFICATIONS Domain** (Tier 1: Org-Scoped)

| Topic Pattern | Tier | Publisher | Subscribers | Payload | Frequency | Latency SLA | Notes |
|---|---|---|---|---|---|---|---|
| `org:{org_id}:notifications:email:queued` | 1 | `Notifications.SendEmail` action | Email delivery tracking | `{event: "email_queued", email_id: UUID, recipient_email: String, template: String, subject: String, queued_at: DateTime}` | Medium | <1s | Email job queued (Oban). Enables user-facing "Email sent" status. Org-scoped. |
| `org:{org_id}:notifications:email:delivered` | 1 | `Oban.Workers.SendEmail` job (callback) | Delivery confirmation UI, audit log | `{event: "email_delivered", email_id: UUID, recipient_email: String, delivered_at: DateTime, provider_id: String}` | Medium | <2s | Email provider confirmed delivery. Updates customer "Ticket email sent" UI. Org-scoped. |

### 2.3 Presence Registry (Phase 3+)

**Phoenix Presence** complements PubSub. While PubSub broadcasts *what happened*, Presence tracks *who is there now*.

**Use Presence for:**
- "5 people are viewing this seat"
- "Someone is hovering Block A"
- "Gate A has 3 active scanners"
- Social proof / FOMO features (Phase 3)

#### Presence Topics

| Topic Pattern | Tier | Purpose | Metadata Tracked | Frequency | Phase | Notes |
|---|---|---|---|---|---|---|
| `presence:org:{org_id}:event:{event_id}:viewers` | 2 | How many users are viewing this event? | `{user_id, distinct_id, connected_at}` | Real-time join/leave | Phase 3 | Each user tracking seating map joins this presence channel. Used to display "XX people browsing". |
| `presence:org:{org_id}:event:{event_id}:seat:{seat_id}` | 2 | Who is hovering/looking at this seat? | `{user_id, action: "hovering"\|"inspecting", hovered_at}` | Real-time | Phase 3 | Users hover over a seat on the map; presence tracks it. Enables "This seat is being looked at" UI indicator. |
| `presence:org:{org_id}:event:{event_id}:block:{block_id}` | 2 | Real-time occupancy per block | `{user_id, action: "selecting"}` | Real-time | Phase 3 | Users selecting from a block trigger presence. Dashboard shows live selection heat map. |
| `presence:org:{org_id}:scanning:gate:{gate_id}` | 2 | Active scanners at this gate | `{device_id, device_name, battery_percent, online_at}` | Real-time | Phase 5 | Scanner devices stay connected to presence channel. Admin dashboard shows "Gate A: 3 devices online (2 battery >50%)". |

#### Presence Implementation Pattern (Phase 3)

```elixir
defmodule VoelgoedEventsWeb.EventLive.Seating do
  use VoelgoedEventsWeb, :live_view
  alias VoelgoedEvents.Topics

  def mount(%{"event_id" => event_id}, _session, socket) do
    org_id = socket.assigns.current_user.organization_id
    
    if connected?(socket) do
      # Join presence channel to track viewer count
      topic = Topics.presence_event_viewers(org_id, event_id)
      {:ok, _} = Phoenix.PresenceClient.track(
        socket,
        topic,
        socket.assigns.current_user.id,
        %{
          user_id: socket.assigns.current_user.id,
          connected_at: DateTime.utc_now()
        }
      )
      
      # Subscribe to presence changes
      Phoenix.PubSub.subscribe(VoelgoedeventsWeb.Endpoint, topic)
    end
    
    {:ok, assign(socket, event_id: event_id, org_id: org_id)}
  end
  
  # Receive presence updates
  def handle_info(
    %{event: "presence_diff", joins: joins, leaves: leaves},
    socket
  ) do
    viewer_count = length(joins) + socket.assigns[:viewer_count]
    {:noreply, assign(socket, viewer_count: viewer_count)}
  end
end
```

---

## 3. Implementation Patterns (Ash Framework)

### 3.1 Configuring Notifiers in an Ash Resource

Ash 3.0 provides `Ash.Notifier` to automatically broadcast PubSub topics when resources change. Here's the pattern:

#### Example: `Seating.Seat` Resource (Tier 2: Event-Scoped)

**File:** `lib/voelgoedevents/ash/resources/seating/seat.ex`

```elixir
defmodule VoelgoedEvents.Ash.Resources.Seating.Seat do
  use Ash.Resource,
    domain: VoelgoedEvents.Seating,
    data_layer: AshPostgres.DataLayer

  # ... attributes, relationships, validations ...

  # Multi-tenancy configuration (required)
  multitenancy do
    strategy :attribute
    attribute :organization_id
  end

  # ✅ Notifier: Broadcast seat state changes via PubSub
  notifiers do
    notifier Ash.Notifier.PubSub do
      # Configure the Phoenix endpoint (required)
      module VoelgoedeventsWeb.Endpoint

      # Define topic template (Tier 2: Event-Scoped)
      # For a Seat with org_id = "abc-123", event_id = "evt-1", action :hold:
      # Topic becomes: org:abc-123:event:evt-1:seating:seat:held
      prefix "org:{organization_id}:event:{event_id}:seating:seat"

      # Broadcast on these actions
      publish :hold, "held"
      publish :release, "released"
      publish :sell, "sold"

      # Custom payload transformer (optional)
      # By default, Ash broadcasts the entire record.
      # Use this to minimize payload size.
      publish_all_updates? false
    end
  end

  # Actions trigger broadcasts
  actions do
    defaults [:create, :update]

    action :hold do
      # Logic: mark seat as held, set held_until TTL
      change Ash.Resource.Change.PassthroughAttribute, :organization_id
      change Ash.Resource.Change.PassthroughAttribute, :event_id
      change set_attribute(:status, :held)
      change set_attribute(:held_until, &calculate_hold_expiry/1)
    end

    action :release do
      change set_attribute(:status, :available)
      change set_attribute(:held_until, nil)
      change set_attribute(:seat_hold_id, nil)
    end

    action :sell do
      change set_attribute(:status, :sold)
      change set_attribute(:ticket_id, &get_ticket_id/1)
      change set_attribute(:sold_at, &DateTime.utc_now/0)
    end
  end
end
```

#### How It Works

1. **Notifier block** declares PubSub as the notification backend.
2. **module:** Points to the Phoenix endpoint that hosts PubSub.
3. **prefix:** Template for topic name. Ash interpolates `{organization_id}` and `{event_id}` from the record.
4. **publish:** Declares which actions trigger broadcasts and the topic suffix.

**Result:** When `Ash.update(seat, %{action: :hold})` succeeds:
- Ash creates the notification
- Topic is resolved: `org:{seat.organization_id}:event:{seat.event_id}:seating:seat:held`
- Broadcast sent **only to subscribers of that event**

### 3.2 Custom Payload Transformation

By default, Ash broadcasts the entire resource record. For large records or to comply with payload size SLAs (Section 5), define a transformer:

```elixir
defmodule VoelgoedEvents.Ash.Resources.Seating.Seat do
  use Ash.Resource, # ...

  notifiers do
    notifier Ash.Notifier.PubSub do
      module VoelgoedeventsWeb.Endpoint
      prefix "org:{organization_id}:event:{event_id}:seating:seat"

      # Publish with custom payload
      publish :hold, "held" do
        payload(:serialize_for_hold)
      end

      publish :release, "released" do
        payload(:serialize_for_release)
      end

      publish :sell, "sold" do
        payload(:serialize_for_sell)
      end
    end
  end

  # Serialization functions (private)
  defp serialize_for_hold(record) do
    %{
      "event" => "seat_held",
      "seat_id" => record.id,
      "block_id" => record.block_id,
      "seat_number" => record.seat_number,
      "user_id" => record.user_id,
      "held_until" => DateTime.to_iso8601(record.held_until),
      "total_held_in_event" => calculate_total_held(record.event_id, record.organization_id)
    }
  end

  defp serialize_for_release(record) do
    %{
      "event" => "seat_released",
      "seat_id" => record.id,
      "block_id" => record.block_id,
      "seat_number" => record.seat_number,
      "reason" => record.release_reason,
      "released_at" => DateTime.to_iso8601(DateTime.utc_now()),
      "total_available_in_event" => calculate_total_available(record.event_id, record.organization_id)
    }
  end

  defp serialize_for_sell(record) do
    %{
      "event" => "seat_sold",
      "seat_id" => record.id,
      "block_id" => record.block_id,
      "seat_number" => record.seat_number,
      "ticket_id" => record.ticket_id,
      "sold_at" => DateTime.to_iso8601(record.sold_at)
    }
  end

  # Helper to count held seats
  defp calculate_total_held(event_id, org_id) do
    Ash.count!(Seat, filter: [event_id: event_id, status: :held, organization_id: org_id])
  end
end
```

**Benefits:**
- Reduces Redis memory footprint (bytes matter at scale)
- Prevents accidental PII leaks (e.g., customer email in broadcast)
- Clarifies which fields are safe to expose to clients

### 3.3 Manual Broadcast (When Ash Notifier Isn't Suitable)

For complex operations spanning multiple resources or when Ash notifier doesn't fit, manually broadcast:

```elixir
defmodule VoelgoedEvents.Ticketing.CompleteCheckout do
  alias VoelgoedEvents.Ticketing
  alias VoelgoedEvents.Seating
  alias VoelgoedEvents.Topics
  require Ash.Query

  def execute(checkout_id, org_id, event_id) do
    # ... validation, seat conversion, accounting, etc. ...

    # Manual broadcast to seating domain (seats sold) - Tier 2
    Enum.each(tickets, fn ticket ->
      Phoenix.PubSub.broadcast(
        VoelgoedeventsWeb.Endpoint,
        Topics.seating_seat_sold(org_id, event_id),
        %{
          "event" => "seat_sold",
          "seat_id" => ticket.seat_id,
          "event_id" => event_id,
          "ticket_id" => ticket.id,
          "sold_at" => DateTime.to_iso8601(DateTime.utc_now())
        }
      )
    end)

    # Manual broadcast to ticketing domain (tickets issued) - Tier 2
    Enum.each(tickets, fn ticket ->
      Phoenix.PubSub.broadcast(
        VoelgoedeventsWeb.Endpoint,
        Topics.ticketing_ticket_issued(org_id, event_id),
        %{
          "event" => "ticket_issued",
          "ticket_id" => ticket.id,
          "ticket_code" => ticket.ticket_code,
          "user_id" => ticket.user_id,
          "event_id" => event_id,
          "price_cents" => ticket.price_cents,
          "issued_at" => DateTime.to_iso8601(DateTime.utc_now())
        }
      )
    end)

    # Broadcast occupancy update - Tier 2
    occupancy = calculate_occupancy(event_id, org_id)
    Phoenix.PubSub.broadcast(
      VoelgoedeventsWeb.Endpoint,
      Topics.seating_occupancy_updated(org_id, event_id),
      %{
        "event" => "occupancy_updated",
        "event_id" => event_id,
        "total_sold" => occupancy.sold,
        "total_held" => occupancy.held,
        "percent_sold" => occupancy.percent_sold,
        "timestamp" => DateTime.to_iso8601(DateTime.utc_now())
      }
    )

    {:ok, tickets}
  end
end
```

**When to Use Manual Broadcast:**
- Orchestrating changes across multiple resources (not single-resource actions)
- Aggregations (occupancy, totals) that don't belong to one record
- Cleanup/background jobs (Oban workers, cron)
- Custom payload logic beyond Ash notifier capabilities

### 3.4 The VoelgoedEvents.Topics Module (Enforce Type Safety)

**Problem:** String interpolation (`"org:#{org_id}:..."`) is a bug factory. One typo (`seating` vs `seated`) breaks the system silently.

**Solution:** Central generator module to enforce schema and prevent mistakes.

**File:** `lib/voelgoedevents/topics.ex`

```elixir
defmodule VoelgoedEvents.Topics do
  @moduledoc """
  Central registry for generating type-safe PubSub topics.
  
  This module enforces naming conventions and prevents typos.
  Always use these functions instead of string interpolation.
  
  Usage:
    Topics.seating_seat_held(org_id, event_id)
    Topics.ticketing_checkout_completed(org_id, event_id)
    Topics.accounts_user_deactivated(org_id)
    Topics.presence_event_viewers(org_id, event_id)
  """

  # ============================================================================
  # TIER 1: Organization-Scoped (Low Volume / Admin)
  # ============================================================================

  def accounts_user_updated(org_id), do: "org:#{org_id}:accounts:user:updated"
  def accounts_user_created(org_id), do: "org:#{org_id}:accounts:user:created"
  def accounts_user_deactivated(org_id), do: "org:#{org_id}:accounts:user:deactivated"
  def accounts_user_role_changed(org_id), do: "org:#{org_id}:accounts:user:role_changed"
  
  def accounts_org_limits_exceeded(org_id), do: "org:#{org_id}:accounts:organization:limits_exceeded"

  def events_event_published(org_id), do: "org:#{org_id}:events:event:published"
  def events_event_cancelled(org_id), do: "org:#{org_id}:events:event:cancelled"
  def events_event_status_changed(org_id), do: "org:#{org_id}:events:event:status_changed"

  def payments_transaction_authorized(org_id), do: "org:#{org_id}:payments:transaction:authorized"
  def payments_transaction_failed(org_id), do: "org:#{org_id}:payments:transaction:failed"
  def payments_ledger_entry_recorded(org_id), do: "org:#{org_id}:payments:ledger:entry_recorded"

  def notifications_email_queued(org_id), do: "org:#{org_id}:notifications:email:queued"
  def notifications_email_delivered(org_id), do: "org:#{org_id}:notifications:email:delivered"

  def scanning_device_online(org_id), do: "org:#{org_id}:scanning:device:online"
  def scanning_device_offline(org_id), do: "org:#{org_id}:scanning:device:offline"

  # ============================================================================
  # TIER 2: Event-Scoped (High Volume / Real-Time)
  # ============================================================================

  # Seating
  def seating_seat_held(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:seating:seat:held"
  def seating_seat_released(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:seating:seat:released"
  def seating_seat_sold(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:seating:seat:sold"
  def seating_occupancy_updated(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:seating:occupancy:updated"
  def seating_block_capacity_critical(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:seating:block:capacity_critical"

  # Ticketing
  def ticketing_ticket_issued(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:ticketing:ticket:issued"
  def ticketing_ticket_voided(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:ticketing:ticket:voided"
  def ticketing_checkout_started(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:ticketing:checkout:started"
  def ticketing_checkout_completed(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:ticketing:checkout:completed"
  def ticketing_checkout_abandoned(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:ticketing:checkout:abandoned"

  # Scanning
  def scanning_scan_admitted(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:scanning:scan:admitted"
  def scanning_scan_denied(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:scanning:scan:denied"
  def scanning_occupancy_updated(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:scanning:occupancy:updated"
  def scanning_fraud_alert(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:scanning:fraud:alert"

  # ============================================================================
  # PRESENCE TOPICS (Phase 3+)
  # ============================================================================

  def presence_event_viewers(org_id, event_id), do: "presence:org:#{org_id}:event:#{event_id}:viewers"
  def presence_seat_hovering(org_id, event_id, seat_id), do: "presence:org:#{org_id}:event:#{event_id}:seat:#{seat_id}"
  def presence_block_selecting(org_id, event_id, block_id), do: "presence:org:#{org_id}:event:#{event_id}:block:#{block_id}"
  def presence_gate_scanners(org_id, gate_id), do: "presence:org:#{org_id}:scanning:gate:#{gate_id}"

  # ============================================================================
  # WILDCARD PATTERNS (for subscriptions)
  # ============================================================================

  def wildcard_event_all(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:*"
  def wildcard_seating_all(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:seating:*"
  def wildcard_scanning_all(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:scanning:*"
  def wildcard_ticketing_all(org_id, event_id), do: "org:#{org_id}:event:#{event_id}:ticketing:*"
  
  def wildcard_org_all(org_id), do: "org:#{org_id}:*"
  def wildcard_accounts_all(org_id), do: "org:#{org_id}:accounts:*"
  def wildcard_events_all(org_id), do: "org:#{org_id}:events:*"
  def wildcard_payments_all(org_id), do: "org:#{org_id}:payments:*"
end
```

#### Usage in LiveView

```elixir
defmodule VoelgoedEventsWeb.EventLive.Seating do
  use VoelgoedEventsWeb, :live_view
  alias VoelgoedEvents.Topics

  def mount(%{"event_id" => event_id}, _session, socket) do
    org_id = socket.assigns.current_user.organization_id

    if connected?(socket) do
      # ✅ Type-safe, no typos possible
      Phoenix.PubSub.subscribe(
        VoelgoedeventsWeb.Endpoint,
        Topics.wildcard_seating_all(org_id, event_id)
      )
    end

    {:ok, socket}
  end

  def handle_info(%{"event" => "seat_held"} = msg, socket) do
    # Handle broadcast
    {:noreply, socket}
  end
end
```

#### Usage in Ash Resource Notifier

```elixir
defmodule VoelgoedEvents.Ash.Resources.Seating.Seat do
  use Ash.Resource, # ...

  notifiers do
    notifier Ash.Notifier.PubSub do
      module VoelgoedeventsWeb.Endpoint
      
      # Use template interpolation; Topics module handles dynamic calls
      prefix "org:{organization_id}:event:{event_id}:seating:seat"

      publish :hold, "held"
      publish :release, "released"
      publish :sell, "sold"
    end
  end
end
```

#### Usage in Manual Broadcasts

```elixir
defmodule VoelgoedEvents.Ticketing.CompleteCheckout do
  alias VoelgoedEvents.Topics

  def execute(checkout_id, org_id, event_id) do
    # ✅ Type-safe broadcast
    Phoenix.PubSub.broadcast(
      VoelgoedeventsWeb.Endpoint,
      Topics.seating_seat_sold(org_id, event_id),
      %{...}
    )
  end
end
```

**Benefits:**
- Eliminates string interpolation typos
- Self-documenting: function name clearly indicates topic
- Easy to refactor: IDE find-and-replace works
- Single source of truth: if topic name changes, update one place

---

## 4. Security & Authorization

### 4.1 Subscriber Validation: Preventing Cross-Tenant Leakage

**CRITICAL RULE:** Every subscription MUST validate that the subscriber's organization matches the topic's `org_id`.

#### Pattern 1: LiveView Mount with Auth Check (Tier 2: Event-Scoped)

```elixir
defmodule VoelgoedEventsWeb.EventLive.Index do
  use VoelgoedEventsWeb, :live_view
  alias VoelgoedEvents.Topics

  def mount(%{"event_id" => event_id}, session, socket) do
    org_id = session["organization_id"]
    
    # Verify org_id exists
    unless org_id do
      {:error, "Missing organization context"}
    end

    # Verify user has access to this event (optional but recommended)
    unless user_has_event_access?(socket.assigns.current_user, event_id) do
      {:error, "Unauthorized"}
    end

    if connected?(socket) do
      # ✅ SAFE: Topic includes org_id and event_id, subscriber is in same org
      Phoenix.PubSub.subscribe(
        VoelgoedeventsWeb.Endpoint,
        Topics.wildcard_event_all(org_id, event_id)
      )
    end

    {:ok, assign(socket, organization_id: org_id, event_id: event_id)}
  end

  def handle_info(%{"event" => "seat_held"} = message, socket) do
    # ✅ Message already scoped to org_id and event_id (from topic prefix)
    # No need to re-validate; Phoenix enforced subscription rules
    {:noreply, update(socket, :seats, &mark_held(&1, message["seat_id"]))}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp user_has_event_access?(user, event_id) do
    # Query to verify user's org owns this event
    case Ash.read_one(
      Event,
      filter: [id: event_id, organization_id: user.organization_id]
    ) do
      {:ok, _} -> true
      :error -> false
    end
  end
end
```

**Key Points:**
1. `session["organization_id"]` is set during login by `VoelgoedEventsWeb.UserAuth` (onmount hook).
2. Subscribe to topics using `Topics` module functions with the session org_id.
3. **Do NOT allow user-supplied org_id in URL params or headers** (e.g., `?org_id=...`). Always trust session.
4. Optionally verify user has access to the specific event (event_id).

#### Pattern 2: UserSocket (WebSocket Connection Auth)

For custom WebSocket connections (e.g., scanner PWA, webhook integrations):

```elixir
defmodule VoelgoedeventsWeb.UserSocket do
  use Phoenix.Socket

  # Authenticate the socket connection
  @impl true
  def connect(params, socket, _connect_info) do
    case params["token"] || params["session_id"] do
      nil ->
        :error

      token ->
        case authenticate_socket(token) do
          {:ok, user_id, org_id} ->
            {:ok, assign(socket, user_id: user_id, organization_id: org_id)}

          :error ->
            :error
        end
    end
  end

  defp authenticate_socket(token) do
    case verify_jwt(token) do
      {:ok, claims} ->
        user_id = claims["user_id"]
        org_id = claims["organization_id"]
        {:ok, user_id, org_id}

      :error ->
        :error
    end
  end

  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"
end
```

#### Pattern 3: Subscription Guard in Channel

```elixir
defmodule VoelgoedeventsWeb.EventChannel do
  use Phoenix.Channel

  @impl true
  def join("org:" <> topic, _payload, socket) do
    # Extract org_id from topic (first component)
    [org_id | _rest] = String.split(topic, ":")

    # Validate subscriber org_id matches topic org_id
    if socket.assigns.organization_id == org_id do
      {:ok, socket}
    else
      {:error, %{"reason" => "unauthorized"}}
    end
  end

  def join(_topic, _payload, _socket) do
    {:error, %{"reason" => "bad_topic_format"}}
  end
end
```

### 4.2 Immediate Session Termination on User Deactivation

When an admin deactivates a user (ban, suspend), all active sessions for that user MUST be killed immediately.

**Implementation:**

```elixir
defmodule VoelgoedEvents.Accounts.DeactivateUser do
  alias VoelgoedEvents.Accounts
  alias VoelgoedEvents.Topics
  require Ash.Query

  def execute(user_id, org_id, reason) do
    # Step 1: Deactivate user in database
    {:ok, _user} =
      Ash.update(user, %{status: :deactivated, deactivated_at: DateTime.utc_now()})

    # Step 2: Broadcast deactivation event (Tier 1: Org-Scoped)
    Phoenix.PubSub.broadcast(
      VoelgoedeventsWeb.Endpoint,
      Topics.accounts_user_deactivated(org_id),
      %{
        "event" => "user_deactivated",
        "user_id" => user_id,
        "reason" => reason,
        "deactivated_at" => DateTime.to_iso8601(DateTime.utc_now())
      }
    )

    {:ok, user}
  end
end

defmodule VoelgoedeventsWeb.UserAuth do
  alias VoelgoedEvents.Topics

  def on_mount(:require_authenticated_user, _params, session, socket) do
    user_id = session["user_id"]
    org_id = session["organization_id"]

    # Subscribe to user deactivation events (Tier 1)
    if connected?(socket) do
      Phoenix.PubSub.subscribe(
        VoelgoedeventsWeb.Endpoint,
        Topics.accounts_user_deactivated(org_id)
      )
    end

    {:cont, socket}
  end

  def handle_info(
    %{"event" => "user_deactivated", "user_id" => deactivated_user_id} = _message,
    socket
  ) do
    if socket.assigns[:user_id] == deactivated_user_id do
      # ✅ This socket belongs to the deactivated user
      # Force disconnect + redirect to login
      {:halt, redirect(socket, to: ~p"/login?reason=deactivated")}
    else
      # Different user deactivated; no action
      {:cont, socket}
    end
  end
end
```

### 4.3 Rate-Limiting Subscriptions

To prevent abuse (e.g., malicious client subscribing to millions of topics):

```elixir
defmodule VoelgoedeventsWeb.SubscriptionLimiter do
  @max_subscriptions_per_socket 20
  @max_wildcard_subscriptions_per_socket 3

  def check_subscription_allowed(socket, topic) do
    current_subs = socket.private[:subscriptions] || []
    current_count = Enum.count(current_subs)
    wildcard_count = Enum.count(current_subs, &String.contains?(&1, "*"))

    cond do
      current_count >= @max_subscriptions_per_socket ->
        {:error, "max subscriptions exceeded"}

      String.contains?(topic, "*") and wildcard_count >= @max_wildcard_subscriptions_per_socket ->
        {:error, "max wildcard subscriptions exceeded"}

      true ->
        {:ok, [topic | current_subs]}
    end
  end
end
```

---

## 5. Payload Specifications

### 5.1 Byte Efficiency Requirements

PubSub broadcasts are **replicated across all nodes** in the cluster and **stored in Redis**. Large payloads waste bandwidth and memory.

**Target: < 1 KB per broadcast**

#### ✅ Efficient Payloads

```json
{
  "event": "seat_held",
  "seat_id": "550e8400-e29b-41d4-a716-446655440000",
  "block_id": "abc123",
  "held_until": "2025-12-07T19:51:00Z",
  "total_held": 42
}
```

Size: ~200 bytes ✓

#### ❌ Inefficient Payloads

```json
{
  "event": "seat_held",
  "seat": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "block_id": "abc123",
    "block": {
      "id": "abc123",
      "name": "Section A",
      "event": {
        "id": "xyz789",
        "name": "Big Concert",
        "capacity": 5000,
        "organization": { ... }
      },
      "pricing_rules": [ ... ],
      "layout_data": { ... }
    },
    "user": {
      "id": "user123",
      "email": "user@example.com",
      "profile": { ... }
    },
    "held_until": "2025-12-07T19:51:00Z"
  }
}
```

Size: >10 KB ✗

### 5.2 Payload Guidelines

| Field | Rule |
|-------|------|
| **event** | REQUIRED. String identifier (e.g., "seat_held"). Enables client-side pattern matching. |
| **IDs** | REQUIRED. UUIDs for entity lookup (e.g., seat_id, ticket_id). Subscribers may need to fetch full record from DB. |
| **Timestamps** | Use ISO 8601 format (e.g., "2025-12-07T19:51:00Z"). Avoid milliseconds unless necessary (<1KB limit). |
| **Counts** | OPTIONAL. Include aggregates (total_held, total_sold) only if needed for client-side UI (e.g., "Seats Held: 42"). Avoid full enums. |
| **User Data** | NEVER include PII (email, phone, full name). IDs only. |
| **Nested Objects** | AVOID. Flatten or include IDs for lazy-fetch. Exceptions: small metadata (block_name, gate_name for UI labels). |
| **Long Strings** | AVOID. Max 255 chars unless reason for detail (error message, refund reason). |
| **Booleans** | Prefer enums (e.g., "status: 'admitted'" vs "admitted: true"). Saves bytes. |

### 5.3 Standard Event Field Structure

Every payload SHOULD follow this template:

```json
{
  "event": "<string>",              // Event name (required)
  "entity_id": "<uuid>",            // Primary entity ID (required)
  "organization_id": "<uuid>",      // For audit (optional, may be in topic)
  "related_ids": {                  // Secondary IDs (optional)
    "user_id": "...",
    "event_id": "..."
  },
  "state_snapshot": {               // Current state (minimal, optional)
    "status": "held|released|sold",
    "count": 42,
    "percent": 84.5
  },
  "timestamp": "<ISO8601>",         // Occurrence time (required)
  "metadata": {                     // Extra context (optional)
    "reason": "ttl_expired",        // For denials, failures
    "source": "api|admin|system"    // Where change originated
  }
}
```

---

## 6. Operational Concerns

### 6.1 Monitoring & Observability

**Key Metrics to Instrument:**

1. **Broadcast Latency:** Time from `Ash.update()` to subscriber `handle_info()`.
   - Target: < 100 ms p95
   - Alert: > 500 ms

2. **Fanout Size:** Number of subscribers per topic.
   - Healthy: < 1000 subscribers per topic
   - Alert: > 5000 (possible resource leak)

3. **Message Rate:** Broadcasts per second across all topics.
   - Target: 100–500 during peak sales
   - Alert: > 5000 (runaway job or spam)

4. **Redis Memory:** Size of PubSub message buffer in Redis.
   - Target: < 100 MB
   - Alert: > 500 MB (messages backing up, subscribers slow)

5. **Subscriber Churn:** New/removed subscriptions per minute.
   - Healthy: < 100
   - Alert: > 1000 (possible bug, frequent reconnects)

**Telemetry Instrumentation:**

```elixir
defmodule VoelgoedEvents.PubSubTelemetry do
  def emit_broadcast(topic, payload_size, latency_ms) do
    :telemetry.execute(
      [:voelgoedevents, :pubsub, :broadcast],
      %{
        count: 1,
        payload_bytes: payload_size,
        latency_ms: latency_ms
      },
      %{topic: topic}
    )
  end

  def emit_subscription(topic, subscriber_count) do
    :telemetry.execute(
      [:voelgoedevents, :pubsub, :subscribers],
      %{count: subscriber_count},
      %{topic: topic}
    )
  end
end
```

### 6.2 Testing PubSub

```elixir
defmodule VoelgoedEventsWeb.SeatingLiveTest do
  use VoelgoedEventsWeb.ConnCase
  import Phoenix.LiveViewTest
  alias VoelgoedEvents.Topics

  describe "seat hold broadcasts" do
    test "seat:held event updates all subscribers" do
      {:ok, live, _html} = live(conn, ~p"/events/123/map")

      # Simulate another user holding a seat
      seat = insert(:seat, event_id: "123", status: :available)
      {:ok, _} = Ash.update(seat, action: :hold)

      # Assert message received
      assert_receive(
        %{
          "event" => "seat_held",
          "seat_id" => ^seat_id
        },
        1000
      )

      # Assert UI updated
      assert render(live) =~ "Held"
    end

    test "cross-tenant isolation" do
      org1_id = "org-1"
      org2_id = "org-2"
      event_id = "event-1"

      {:ok, socket1} = live_connect(org1_id, event_id)
      {:ok, socket2} = live_connect(org2_id, event_id)

      # Hold a seat in org1
      seat = insert(:seat, organization_id: org1_id, event_id: event_id, status: :available)
      Ash.update(seat, action: :hold)

      # Assert org1 subscriber receives
      assert_receive(%{"event" => "seat_held"}, 1000)

      # Assert org2 subscriber does NOT receive (different org)
      refute_receive(%{"event" => "seat_held"}, 100)
    end

    test "event isolation within org" do
      org_id = "org-1"
      event1_id = "event-1"
      event2_id = "event-2"

      # User viewing event 1
      {:ok, socket1} = live_connect(org_id, event1_id)
      
      # User viewing event 2
      {:ok, socket2} = live_connect(org_id, event2_id)

      # Hold a seat in event 1
      seat = insert(:seat, organization_id: org_id, event_id: event1_id, status: :available)
      Ash.update(seat, action: :hold)

      # Assert event1 subscriber receives
      assert_receive(%{"event" => "seat_held"}, 1000)

      # Assert event2 subscriber does NOT receive (different event)
      refute_receive(%{"event" => "seat_held"}, 100)
    end
  end
end
```

### 6.3 Runaway Broadcasts (Prevention)

**Problem:** A buggy action broadcasts on every state change, flooding subscribers.

**Prevention:**

1. **Code Review:** Inspect all new publish directives.
2. **Rate Limiting:** Batch broadcasts; debounce rapid state changes.

```elixir
defmodule VoelgoedEvents.OccupancyBroadcaster do
  use GenServer
  alias VoelgoedEvents.Topics

  def start_link(org_id) do
    GenServer.start_link(__MODULE__, org_id, name: :"#{org_id}:occupancy_broadcaster")
  end

  def init(org_id) do
    {:ok, %{org_id: org_id, timer: nil}}
  end

  # Debounced broadcast: delay 5 seconds before emitting
  def trigger_broadcast(org_id, event_id) do
    GenServer.cast(:"#{org_id}:occupancy_broadcaster", {:trigger, event_id})
  end

  def handle_cast({:trigger, event_id}, state) do
    # Cancel existing timer
    if state.timer, do: Process.cancel_timer(state.timer)

    # Schedule new broadcast in 5 sec (batches rapid updates)
    timer = Process.send_after(self(), {:broadcast, event_id}, 5000)
    {:noreply, %{state | timer: timer}}
  end

  def handle_info({:broadcast, event_id}, state) do
    # Broadcast once after 5 sec of silence
    occupancy = calculate_occupancy(event_id, state.org_id)
    Phoenix.PubSub.broadcast(
      VoelgoedeventsWeb.Endpoint,
      Topics.seating_occupancy_updated(state.org_id, event_id),
      occupancy
    )
    {:noreply, %{state | timer: nil}}
  end
end
```

3. **Monitoring:** Alert on spike in message count.

---

## 7. Future Extensions (Phase 3)

### 7.1 Interactive Seating Charts (Thousands of Concurrent Users)

**Challenge:** Real-time map with thousands of concurrent seat selections.

**Current Pattern (Phase 2):**
- Broadcast `org:X:seating:seat:held` for every user action
- All users subscribe to `org:X:seating:seat:*`
- At 5 seats/sec per event, clients may receive 5+ msgs/sec → O(n) network load

**Implemented (Phase 3+):**
- ✅ Use event-scoped topics: `org:X:event:Y:seating:seat:held`
  - Users subscribe to **their event only**, not org-wide
  - Reduces message fanout by event count
  - With 5 concurrent events, 5x reduction in client message volume

- **Future optimizations (Phase 3.5):**
  - Compress payloads: "seats_held: [id1, id2, id3]" instead of 3 separate events
  - Client-side throttling: coalesce 10 broadcasts → 1 UI update
  - Presence tracking: "5 people are viewing Block A" (see Section 2.3)

### 7.2 Offline Scanning Device Sync

**Challenge:** Scanner device goes offline (WiFi loss), accumulates scans in IndexedDB, syncs when back online.

**Current Pattern:** Manual offline queue (see `offline_sync.md`).

**Planned Enhancement:**
- Emit `org:X:scanning:offline_batch:synced` on successful batch upload
- Device subscribes to this topic to confirm sync completion
- Enables "green checkmark" UI for queued-then-synced scans

### 7.3 Cross-Organization Admin Dashboard (Future Multi-Org View)

**Planned:** Allow super-admins to view metrics across all orgs.

**Strategy:**
- **Separate admin topic namespace:** `admin:metrics:occupancy:*` (NOT org-scoped)
- **Aggregation service:** Subscribes to all org topics, publishes to admin topics
- **Access Control:** Only super-admins can subscribe to admin topics

---

## Appendix: Quick Reference

### Topic Naming Checklist

Before adding a new topic, verify:

- [ ] Determine if Tier 1 (Org-Scoped) or Tier 2 (Event-Scoped)
  - High volume (>10/sec)? → Tier 2
  - Low volume (admin)? → Tier 1
- [ ] Follows correct pattern:
  - Tier 1: `org:{org_id}:{domain}:{entity}:{action}`
  - Tier 2: `org:{org_id}:event:{event_id}:{domain}:{entity}:{action}`
- [ ] No CamelCase, uses lowercase
- [ ] Added to Topic Registry (Section 2)
- [ ] Added to VoelgoedEvents.Topics module (Section 3.4)
- [ ] Payload < 1 KB
- [ ] No PII in payload
- [ ] All subscribers validate org_id (and event_id for Tier 2) match
- [ ] Test for cross-tenant isolation
- [ ] Test for cross-event isolation (Tier 2 only)

### Testing Checklist

- [ ] Subscribers receive correct message
- [ ] Cross-tenant isolation (org A can't receive org B's broadcasts)
- [ ] Cross-event isolation (event A subscribers don't receive event B broadcasts)
- [ ] Wildcard subscriptions work
- [ ] Payload matches spec (Section 5)
- [ ] Latency < 100 ms p95
- [ ] Unsubscribe cleans up resources

### Security Checklist

- [ ] org_id extracted from session (not URL/params)
- [ ] event_id (for Tier 2) verified against user's org membership
- [ ] Subscription validates org_id == topic org_id
- [ ] Subscription validates event_id == topic event_id (Tier 2)
- [ ] User deactivation broadcasts and kills sessions
- [ ] No payload contains PII (email, phone, SSN, etc.)
- [ ] Rate limiting prevents subscription spam
- [ ] Audit logs all subscription events (optional but recommended)

### Phase Transition Checklist

**Phase 2 → Phase 3 (Interactive Seating):**
- [ ] All Seating topics migrated to Tier 2 (event-scoped)
- [ ] All Ticketing topics migrated to Tier 2
- [ ] All Scanning ticket topics migrated to Tier 2
- [ ] VoelgoedEvents.Topics module deployed and in use
- [ ] LiveViews updated to use Topics module functions
- [ ] Cross-event isolation tests passing
- [ ] Presence topics stubbed (implement Phase 3.1)
- [ ] Occupancy broadcaster debouncing enabled

---

**End of Document**

*For questions or updates, contact the Backend Architecture team.*

*Last Updated: 2025-12-07 Rev 2*  
*Status: Production-Ready (Tier 1 + Tier 2 Complete, Presence for Phase 3)*  
*Approver: Senior Principal Software Architect*
