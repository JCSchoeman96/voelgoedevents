# Scaling & Resilience Architecture  
VoelgoedEvents Platform  
**Document: `/docs/architecture/09_scaling_and_resilience.md`**

---

## 1. Purpose of This Document

This document defines the **scaling strategy**, **high-availability design**, and **resilience guarantees** for the VoelgoedEvents platform.

It ensures the system can:

- Handle flash-sale ticket spikes  
- Support 100k+ concurrent users  
- Sustain continuous real-time updates  
- Maintain availability during node failures  
- Prevent overselling under extreme load  
- Provide predictable performance at scale  
- Auto-recover from failure scenarios  
- Support multi-region growth  

This is the authoritative reference for all scaling, throughput, and resilience decisions across all vertical slices and domains.

---

## 2. Architecture Philosophy

### VoelgoedEvents prioritizes:

1. **Correctness under load** (no oversell, no cross-tenant mix-ups)  
2. **Real-time responsiveness**  
3. **Graceful degradation**  
4. **Predictable performance**  
5. **Horizontal scalability**  
6. **Fault tolerance**  
7. **Infrastructure efficiency**  

Scaling is built around the **Hot → Warm → Cold** architecture:

- **Hot**: ETS + GenServers  
- **Warm**: Redis cluster  
- **Cold**: Postgres + read replicas  

This ensures stability during traffic spikes, flash-sale loads, and real-time scanning operations.

---

## 3. Horizontal Scaling Strategy

VoelgoedEvents scales by adding more nodes:

### 3.1 Phoenix Application Nodes

Scaling effect:

- More LiveView connections  
- Higher throughput for REST/SvelteKit endpoints  
- Better real-time fan-out capacity  

LiveView is inherently scalable due to efficient diffing.

### 3.2 Worker Nodes (Oban)

Scaling effect:

- Higher background job throughput  
- Faster notification + webhook queues  
- More capacity for payment reconciliation  
- Better resilience for scheduled tasks  

Worker nodes are stateless and horizontally scalable.

### 3.3 Redis Cluster Nodes

Redis scales:

- Seat availability bitmaps  
- Seat hold ZSETs  
- Analytics streams  
- Rate limits  
- Device-scanning throughput keys  
- Queues for notifications/webhooks  

Redis cluster ensures high write throughput for volatile real-time data.

### 3.4 Postgres Read Replicas

Read replicas support:

- Reporting  
- Analytics queries  
- Heavy admin dashboards  
- Real-time monitoring panels  

All heavy reads must target read replicas.

---

## 4. Flash-Sale Scaling Architecture

Flash sales are the most intense load profile VoelgoedEvents must handle.

### 4.1 Flash-Sale Constraints

- **Synchronous seat allocation** must be safe  
- **DB must never be hit directly** for availability checks  
- **Redis must be atomic and correct**  
- **ETS must be used for read hot-paths**  
- **PubSub propagation <150ms**  
- **90%+ of requests served without DB touch**  

### 4.2 Flash-Sale Checklist

| Component | Role |
|----------|------|
| ETS | Hot availability snapshot / membership / price rules |
| Redis | Seat-hold registry, bitmaps, counters |
| Phoenix | Real-time interaction handler |
| Postgres | Final writes only |
| Oban | Async tasks to offload heavy work |
| CDN | Static content offload |
| Rate Limiter | Abuse shielding |

### 4.3 Flash-Sale Preloading

Before a sale:

- Seat maps loaded into ETS  
- Seat bitmaps pre-warmed in Redis  
- Price rules cached across nodes  
- Event dashboards placed in watch mode  
- Queueing system enabled (web/API)  

### 4.4 Queueing System (Optional for Very High Load)

Virtual queue behaviors:

- Assign arrival rank  
- Throttle throughput from queue to app  
- Prevent stampedes  
- Much easier horizontal scaling under insane load  

---

## 5. Real-Time Scaling Architecture

### 5.1 LiveView Scaling

LiveView:

- Supports millions of concurrent updates  
- Scales horizontally as nodes are added  
- Uses Phoenix PubSub to distribute events  
- Requires per-tenant topic partitioning  
- Uses ETS for ultra-fast read local state  

### 5.2 PubSub Scaling

PubSub relies on:

- Distributed Erlang  
- Fast broadcast via node mesh  
- Subcluster/local node subscriptions for devices  

Optional: using Phoenix Presence for realtime occupancy tracking.

### 5.3 Redis Stream Scaling

Used for:

- Analytics  
- Funnels  
- Scan logs  
- Device sync  
- Event backpressure  

Streams scale via:

- Sharding by event_id  
- Automatic trimming  
- Dedicated consumer groups  

---

## 6. Failure Detection & Self-Healing

### 6.1 Node Failure

If a node fails:

- Load balancer removes it  
- Sessions reconnect via Phoenix presence & LiveView fallback  
- ETS rebuilt locally from Redis  
- Oban jobs failover to other nodes  
- Domain events redistributed automatically  

No user impact expected.

---

### 6.2 Redis Outage

Single Redis node: failover via sentinel or cluster.

Temporary Redis unavailability:

- ETS serves stale reads for <10s  
- Writes temporarily rejected or queued  
- Device scanning moves to degraded mode (server timestamps + retry)  
- Queueing system limits damage  
- System recovers once Redis returns  

### 6.3 Postgres Partial Outage

- Read replicas continue serving reads  
- Writes fail fast  
- System moves into read-only mode for some operations  
- Takes advantage of cached state in ETS and Redis  

### 6.4 Postgres Full Outage

Expected behavior:

- Serve cached/non-mutative functionality  
- Disable checkouts  
- Disable ticket issuance  
- Disable scanning write operations  
- Serve dashboards from last known cached data  
- Queue writes for later replay (optional future feature)  

---

## 7. Resilience Techniques

### 7.1 Circuit Breakers

Used for:

- PSP integrations  
- Notification providers  
- Webhook systems  
- Expensive external APIs  

### 7.2 Bulkheads

Pools separated by:

- Domain  
- Queue type  
- Tenant or event group  

Prevents cascading failures.

### 7.3 Timeouts Everywhere

All remote operations must have:

- Short timeouts  
- Fallback behavior  
- Retry policies  

### 7.4 Backpressure

Mechanisms:

- Queue-based throttling (Oban)  
- Rate limiting (Redis counters)  
- Virtual waiting rooms  
- Circuit-breaker fallback modes  

---

## 8. Multi-Region Scaling (Future-Ready)

VoelgoedEvents supports future expansion into global regions.

### Architecture Considerations:

- Redis cluster per region  
- Postgres primary per region (or multi-primary with CRDTs when needed)  
- Global traffic routing (GeoDNS)  
- Region-local seats caches  
- Region-local availability bitmaps  
- Eventual consistency across regions via streams  

### Multi-Region Goal:

> Ultra-low latency event browsing, scanning, and dashboards regardless of geography.

---

## 9. Caching Strategy for Large Scale

Caching layers support high throughput:

### 9.1 ETS

Use for:

- Membership  
- Pricing  
- Availability snapshots  
- Recent scanning results  
- Recently touched tickets  

### 9.2 Redis

Use for:

- Inventory  
- Seat holds  
- Queues  
- Counters  
- Funnels  
- Rate limits  

### 9.3 Postgres

Use for:

- Durable storage  
- Reporting  
- Large coordinated transactions  
- Ledger integrity  

---

## 10. Scaling Domain-Specific Operations

### 10.1 Ticketing / Seat Selection

Critical scaling rules:

- Redis bitmaps for availability  
- Redis ZSET for holds  
- ETS snapshot for UI  
- LiveView deltas for instant updates  

### 10.2 Scanning

Requirements:

- Sub-50ms response time  
- Duplicate detection via ETS  
- Final validation via Redis  
- Event-level heavy reads offloaded to Postgres replicas  

### 10.3 Payments

Requirements:

- PSP timeouts must not block flows  
- Payment capture async  
- Reconciliation via Oban  
- Ledger must remain consistent  

### 10.4 Analytics

- Writes into Redis streams  
- Read via materialized Postgres views  
- High-frequency counters in Redis  
- Aggregation jobs periodically compact historical data  

---

## 11. Observability & Monitoring

Monitoring must include:

- p50/p90/p99 latency per endpoint  
- Redis latency & throughput  
- ETS hit/miss ratio  
- PubSub propagation latency  
- Oban job queue depth  
- Postgres slow queries  
- Flash-sale alarms  
- Multi-tenant anomaly detection  
- Device scanning error rate  
- Backoff trigger counts  
- Rate limit violations  

All telemetry must include:

- `organization_id`  
- `event_id`  
- `slice`  
- `service_type`  

---

## 12. Stress Testing Framework

The platform must regularly run:

- **Load tests** (10k–100k concurrent users)  
- **Seat-selection stress tests**  
- **Scanning throughput tests**  
- **Checkout performance tests**  
- **PubSub broadcast saturation tests**  
- **Redis atomic pipeline tests**  
- **Cache stampede simulations**  
- **Node failure chaos tests**  
- **Regional failover drills**  

---

## 13. Summary

The VoelgoedEvents scaling and resilience strategy is built upon:

- Horizontal scalability across all tiers  
- Strong isolation and recovery boundaries  
- Real-time fault-tolerance  
- Multi-layer caching (ETS → Redis → Postgres)  
- Flash-sale readiness and no-oversell guarantees  
- Multi-region future expansion  
- Continuous monitoring & auto-recovery mechanisms  
- Vertical-slice independence for scaling by feature  
- Reliable throughput for payments, scanning, and ticketing  

This document defines how the system stays fast, correct, and operational even under extreme conditions.

