# Ephemeral / Real-Time State Domain

## 1. Purpose & Scope

This domain models all **non-persistent**, real-time, short-lived application state used across the platform.  
It is the performance backbone of the system.

It includes:

- Hot in-memory state (ETS, GenServers)
- Warm distributed state (Redis)
- Real-time event streams (PubSub topics)
- State machines that govern temporary workflows (checkout, seat holds)
- Caches for availability, pricing, occupancy, rate limits, counters
- Sync points for offline/online consistency (e.g., scanning devices)

This domain is *not* stored in Postgres. Persistence belongs to each vertical slice domain.

---

## 2. Why This Domain Exists

The VoelgoedEvents platform targets:

- **100k concurrent users**
- **Flash-sales without oversell**
- **Sub-100ms latency**
- **Real-time dashboards**
- **Mobile scanning with 0–1s response**

Postgres cannot serve these needs alone.

This domain ensures:

- High-throughput reads
- Concurrency-safe writes
- Fast mutation workflows
- State isolation between vertical slices
- No thundering herd
- No overselling or inconsistent reads

It is the **"operational memory"** of the whole system.

---

## 3. Categories of Ephemeral State

### 3.1 Hot State (ETS / GenServer)

Lifetime: **milliseconds → minutes**  
Location: **local BEAM node memory**  
Used for:

- Seat availability snapshots (bloom filters, bitmaps)
- Membership & RBAC caching
- Event summaries for dashboards
- Cart/checkout short-lived state
- Price-computation caches
- Throttle & dedupe guards
- Recent scan results

Properties:

- Ultra-fast
- Node-local
- Volatile
- Rebuilt from Redis or DB on boot

---

### 3.2 Warm State (Redis)

Lifetime: **minutes → days**  
Location: **Redis cluster**

Used for:

- Seat holds (ZSET)
- GA inventory counters
- Ticket scan flags
- Rate limits (per-minute/hour)
- Access key verification caches
- Funnel events (streams)
- Webhook dedupe
- Outgoing task queues
- Report job queues
- Offline scanning sync data

Properties:

- Distributed
- Fast reads & atomic writes
- Ordered operations (ZSET)
- Expiration-based lifecycle
- Durable across node restarts (but not a source of truth)

---

### 3.3 Cold State (Postgres)

Not part of this domain directly—but every ephemeral structure ties back to a persistent source.

---

## 4. Core Real-Time Artifacts

Below are the standard “objects” managed by this domain.

### 4.1 **Availability Snapshots**

Representing the current availability of GA or seated tickets.

Stored as:

- **Redis bitmap** — one bit per seat  
- **ETS map** — compressed availability for active checkouts  
- **Redis hash** — GA counters

Used by:

- Ticketing  
- Seating  
- Checkout  
- Dashboards  

---

### 4.2 **Seat Holds**

The canonical volatile registry of temporary ownership in checkout.

- Stored in Redis ZSET:  
  `ticketing:holds:event:{event_id}` → `( seat_id, expires_at )`
- Mirrored in ETS for microsecond-level access
- Released automatically after expiry
- Prevents oversell under concurrency

---

### 4.3 **Checkout States**

Cart + progress to payment.

Stored as:

- ETS:
  - `checkout:{cart_id}:summary`
  - Short TTL; node-local
- Redis:
  - `checkout:{cart_id}:state` (fallback)
  - `checkout:locks:{cart_id}` (rate limit)

---

### 4.4 **Scanning Session State**

- Ticket scanned flags in Redis (`scan:ticket:{ticket_id}`)
- Recent scans cached in ETS
- Real-time throughput counters (Redis)
- Offline sync queues

---

### 4.5 **Rate Limits & Quotas**

All API / webhook / notification quotas are ephemeral:

- Rate limit counters in Redis
- Per-key/per-IP counters
- Sliding window TTL expiration

---

### 4.6 **Real-Time Event Streams**

Using Phoenix PubSub:

- `events:event:{event_id}`
- `ticketing:event:{event_id}`
- `seating:event:{event_id}`
- `scanning:event:{event_id}`
- `analytics:event:{event_id}`

Purpose:

- Push-based UIs
- Instant dashboards
- Reactive SvelteKit Live Data views

---

## 5. Redis Key Structures

### Seat State
seating:availability:{event_id} (bitmap or hash)
seating:layout:{layout_id} (hash)

shell
Copy code

### Ticketing State
ticketing:holds:event:{event_id} (ZSET)
ticketing:inventory:ga:{type_id} (hash/counter)
ticketing:pricing:effective:{type_id}(hash)
ticketing:coupon_uses:{coupon_id} (counter)

shell
Copy code

### Scanning State
scan:ticket:{ticket_id} (flag)
scan:session:{session_id} (counters)

shell
Copy code

### API & Rate Limits
api:rate:{key_id}:{period} (counter)
api:key:{key_id}:scopes (set)

shell
Copy code

### Notifications
notifications:queue:{org_id} (list)
notifications:rate:{org_id}:{chan} (counter)

shell
Copy code

### Integrations
webhook:incoming:dedupe:{id} (string)
webhook:outgoing:queue:{org_id} (list)

shell
Copy code

### Reporting
reporting:queue:{org_id} (list)
reporting:lock:{definition_id} (string)

yaml
Copy code

---

## 6. Indexing & Query Patterns

No SQL indexes — but **access patterns matter**:

### Reads
1. ETS → 50–100µs  
2. Redis → 1–3ms  
3. Postgres → 3–10ms  

### Writes
- Redis atomic ops for correctness (INCR, ZADD, HINCRBY)
- GenServers for serializing hot-path writes

### Patterns
- Load → mutate → write-through to Redis/ETS
- Avoid hydration of large objects into memory (stream where possible)

---

## 7. Real-Time PubSub

PubSub is the messaging layer for:

- LiveViews
- SvelteKit subscribers
- Device sync
- Dashboards
- Admin panels

Rules:

- Redis never publishes  
- Phoenix PubSub does  
- Ephemeral domain orchestrates these flows

---

## 8. Error & Edge Cases

- Cache stampede → mitigate with request coalescing
- Redis failover → fall back to Postgres + temporary degraded mode
- ETS corruption if node dies → rebuild from Redis on restart
- Inconsistent seat state:
  - Always rebuild from ZSET + sold tickets table

---

## 9. Domain Interactions

This domain supports **every other domain**:

- **Ticketing** → availability, holds, pricing  
- **Seating** → real-time occupancy  
- **Scanning** → instant validation  
- **Payments** → retry locks  
- **Notifications** → delivery queues  
- **API** → rate limits  

It is the performance engine of the platform.

---

## 10. Testing & Observability

Tests:
- Concurrency tests
- Redis key consistency validation
- Node restart scenarios (ETS rebuild)

Telemetry:
- Redis latency
- Cache hit rates
- PubSub delivery latency
- Seat-hold expiry rates

---

## 11. Future Extensions

- Redis cluster sharding (slots per event)
- Ephemeral session replay log
- Real-time fraud detection
- On-the-fly read replicas for event spikes
