# VoelgoedEvents: Scanner Offline Sync Protocol

**File Path:** `docs/workflows/scanner_offline_sync.md`

*Last Updated: 2025-12-07 (Initial)*  
*Status: Production-Ready Specification*  
*Audience: Mobile engineers, backend engineers, security architects*  
*Scale Target: 20,000+ tickets, 50+ devices, 5,000+ concurrent guests, <30 min entry processing*

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [System Architecture & Design Principles](#1-system-architecture--design-principles)
3. [Phase 1: Hydration (Manifest Download)](#2-phase-1-hydration-manifest-download)
4. [Phase 2: Local Validation (Offline Brain)](#3-phase-2-local-validation-offline-brain)
5. [Phase 3: Sync Protocol (Device → Server)](#4-phase-3-sync-protocol-device--server)
6. [Phase 4: Server-Side Reconciliation](#5-phase-4-server-side-reconciliation)
7. [Ash Resources & Domain](#6-ash-resources--domain)\n8. [Security & Anti-Spoofing](#7-security--anti-spoofing)
9. [Device Pairing & Authorization](#8-device-pairing--authorization)
10. [Conflict Resolution Matrices](#9-conflict-resolution-matrices)
11. [Observability & Telemetry](#10-observability--telemetry)
12. [Implementation Guide](#11-implementation-guide)
13. [Testing & Chaos Scenarios](#12-testing--chaos-scenarios)
14. [Disaster Recovery](#13-disaster-recovery)

---

## Executive Summary

**Problem:** VoelgoedEvents must validate 5,000+ tickets at event gates within 30 minutes, on 50+ mobile devices, with **zero internet connectivity guarantees**. Every second of delay = denied entry = customer anger.

**Solution:** A four-phase protocol combining **client-side IndexedDB validation** (offline) with **server-side HMAC-signed manifest delivery** and **deterministic conflict resolution** based on cryptographic signatures and timestamp ordering.

### Key Design Principles

1. **Device is Trusted (But Verified)** — Device can validate tickets offline using signed manifest; server trusts device claims *only if cryptographically proven*
2. **Timestamp is Source of Truth** — `scanned_at` from device (with offset correction) determines scan order globally
3. **Manifest Signature Prevents Tampering** — HMAC-SHA256 ensures manifest authenticity; device rejects unsigned/mismatched signatures
4. **Idempotency is Mandatory** — Same `scan_id` sent twice = processed once (prevents replay attacks)
5. **Conflict Detection, Not Prevention** — Server detects collisions (double-scans, invalid barcodes) *after* sync; flags for manual review
6. **Circuit Breaker Sync** — Device retries failed syncs with exponential backoff; never loses data
7. **Observable at Every Layer** — Telemetry on manifest freshness, scan latency, sync success rate, conflict frequency

### Expected Outcomes

| Metric | Target | Achievement |
|--------|--------|---|
| **Offline Latency (Scan)** | <200ms | IndexedDB lookup |
| **Sync Latency (Device Online)** | <2s for 50 items | Batch POST + DB insert |
| **Manifest Freshness** | <5 min old | Hydration before gates open |
| **Double-Scan Detection** | 100% | Timestamp-based conflict resolution |
| **Data Integrity** | No loss | Idempotency + retries |
| **Availability** | 99.99% | Fallback scanning (manual, QR codes) |

---

## 1. System Architecture & Design Principles

### 1.1 Critical Invariants

**INVARIANT 1: Manifest is Immutable**
```
Once device downloads manifest at T+0, it is LOCKED.
- Timestamp stored: manifest_downloaded_at
- If new tickets added to event: Device must re-hydrate
- Old manifest = old truth for that device
  (Allows multi-device reconciliation)
```

**INVARIANT 2: Device Clock May Drift**
```
Device clock may be +/- 60 seconds off.
Server provides offset_correction = server_time - device_time.
Device stores and uses it for all future scans:
  canonical_scanned_at = device_scanned_at + offset_correction
```

**INVARIANT 3: Scan ID is Idempotent Key**
```
scan_id = UUID v4 generated locally
If POST /sync includes scan_id "xyz" twice (network retry),
server processes ONCE.
NEVER returns "duplicate scan_id" error.
Returns: {processed: [scan_id], skipped: []}
```

**INVARIANT 4: Timestamp Determines Order**
```
If two devices scan same ticket:
  Device A: scanned_at = 19:30:00 (with offset applied)
  Device B: scanned_at = 19:30:01
Result: Device A's scan is "first", Device B's is "duplicate".
NEVER: "One device didn't sync yet, so we don't know."
(Offset mechanism makes all times global-ish.)
```

**INVARIANT 5: Manifest Signature Prevents Tampering**
```
Manifest = {tickets: [...], gates: [...]}
Signature = HMAC-SHA256(manifest_json, server_secret)

Device receives:
  manifest + X-Signature header
Device validates:
  HMAC-SHA256(received_manifest_json, device_api_key) == X-Signature
If mismatch: REJECT and log security alert.
If attacker swaps ticket hash: Signature breaks.
```

---

## 2. Phase 1: Hydration (Manifest Download)

### 2.1 Endpoint: GET /api/scanning/events/:id/manifest

**Purpose:** Device downloads the "truth" for an event (all valid ticket hashes, gate rules, access zones).

### 2.2 Response Payload Structure

```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_name": "Paris Music Festival 2025",
  "manifest_version": 3,
  "generated_at": "2025-12-07T17:45:00Z",
  "expires_at": "2025-12-07T22:00:00Z",
  "offset_seconds": 5,
  "gates": [
    {
      "gate_id": "north-main",
      "name": "North Entrance - Main",
      "access_rules": {
        "zones": ["general", "vip"],
        "max_concurrent": 1000,
        "entry_rules": ["check_ticket_valid", "check_not_duplicate"]
      }
    }
  ],
  "tickets": [
    {
      "ticket_id": "tkt-001",
      "barcode_hash": "sha256:a3f8c2e1d5b9f7a4c6e2d8f1b3a5c7e9f2d4a6b8c0e2f4a6b8d0e2f4a6b8",
      "zone": "general",
      "gate_ids": ["north-main"],
      "entry_limit": 1,
      "is_valid": true,
      "expires_at": "2025-12-07T22:00:00Z"
    }
  ],
  "signature": "HMAC-SHA256=a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0"
}
```

### 2.3 Manifest Signature Generation (Server)

Server signs manifest using HMAC-SHA256 with device's API key. Device verifies signature before storing in IndexedDB.

### 2.4 Client-Side Hydration (Svelte)

- Fetch manifest from server
- Verify HMAC-SHA256 signature against device API key
- Store manifest metadata in IndexedDB
- Build ticket lookup table (barcode_hash → ticket_info)
- All subsequent scans reference this downloaded manifest

---

## 3. Phase 2: Local Validation (Offline Brain)

### 3.1 Scan Detection: Client-Side Decision Tree

**When a guest scans a barcode at the gate:**

```
INPUT: Scanned barcode (raw text)
         ↓
STEP 1: Calculate barcode hash
 barcode_hash = SHA256(scanned_barcode)
         ↓
STEP 2: Lookup in IndexedDB
 ticket = tickets[barcode_hash]
    ↓ (not found)        ↓ (found)
    │                    │
    ├─ RED (Stop)        ├─ Check gate access
    │  reason: Invalid   │  Is gate in ticket.gate_ids?
    │                    │
    └─ Queue scan        ├─ NO → RED (Stop)
                         │  reason: Wrong gate
                         │
                         ├─ YES → Check duplicate
                         │  scanned_tickets = localScanLog[ticket.ticket_id]
                         │  Has entry.entry_limit been reached?
                         │
                         ├─ YES → RED (Stop)
                         │  reason: Already scanned
                         │
                         └─ NO → Final checks
                            ├─ Ticket expired? → RED
                            └─ Valid? → GREEN (Go)
```

### 3.2 Local Scan Log Storage

All scans performed on device stored in IndexedDB with fields:
- `scan_id`: UUID v4 (idempotency key)
- `ticket_id`: Which ticket
- `barcode`: Original scanned barcode
- `scanned_at`: Device timestamp (ISO 8601)
- `scanned_at_corrected`: With offset applied
- `gate_id`: Which gate
- `outcome`: 'valid', 'duplicate', 'invalid', 'gate_access_denied'
- `sync_status`: 'pending', 'synced', 'failed'
- `retry_count`: Number of sync attempts

---

## 4. Phase 3: Sync Protocol (Device → Server)

### 4.1 Endpoint: POST /api/scanning/sync

**Purpose:** Device uploads batch of scans when connectivity is restored.

### 4.2 Request Payload

```json
{
  "device_id": "device-550e8400-e29b-41d4-a716-446655440000",
  "sync_batch_id": "batch-550e8400-e29b-41d4-a716-446655440000",
  "offset_seconds": 5,
  "scans": [
    {
      "scan_id": "scan-uuid-1",
      "ticket_id": "tkt-001",
      "barcode_hash": "sha256:a3f8c2e1d5b9f7a4c6e2d8f1b3a5c7e9f2d4a6b8c0e2f4a6b8d0e2f4a6b8",
      "scanned_at": "2025-12-07T19:30:00Z",
      "gate_id": "north-main",
      "outcome": "valid",
      "signature": "HMAC-SHA256=x1y2z3..."
    }
  ]
}
```

**Field Breakdown:**

| Field | Type | Purpose | Constraints |
|-------|------|---------|-----------| 
| `device_id` | UUID | Which device | Must match authenticated device |
| `sync_batch_id` | UUID | Batch identifier | Idempotency key for entire batch |
| `offset_seconds` | Integer | Clock offset correction | server_time - device_time |
| `scans` | Array | List of scans | Max 50 per request (prevents timeouts) |
| `scans[].scan_id` | UUID | Individual scan ID | Idempotency key per scan |
| `scans[].ticket_id` | UUID | Which ticket | From manifest |
| `scans[].barcode_hash` | String | SHA256 hash | For verification |
| `scans[].scanned_at` | ISO 8601 | Device-reported time | Will be adjusted by offset |
| `scans[].gate_id` | String | Which gate | For access audit |
| `scans[].outcome` | String | Local validation result | 'valid', 'duplicate', 'invalid', etc. |
| `scans[].signature` | String | HMAC of scan data | Prevents tampering |

### 4.3 Scan Signature Generation (Client)

Each scan must be signed to prevent the device from forging scans post-hoc:

```
scanData = {
  scan_id: uuid,
  ticket_id: uuid,
  barcode_hash: hash,
  scanned_at: ISO8601,
  gate_id: string
}

signature = HMAC-SHA256(JSON.stringify(scanData), device_api_key)
```

### 4.4 Batching & Retry Strategy

- Default batch size: 50 scans per request
- Exponential backoff: 1s → 2s → 4s → 8s → 16s (max 30s)
- Max retries: 5 attempts per batch
- Never lose data: Failed scans remain in IndexedDB until synced

---

## 5. Phase 4: Server-Side Reconciliation

### 5.1 Sync Processing Logic

```
1. Authenticate device (Bearer token)
2. Check idempotency (is this batch_id already processed?)
   ├─ YES: Return cached result
   └─ NO: Process new batch

3. For each scan:
   a. Verify scan signature (HMAC)
   b. Check idempotency (is this scan_id already recorded?)
      ├─ YES: Skip (don't reprocess)
      └─ NO: Continue
   c. Fetch ticket from database
   d. Apply offset: canonical_scanned_at = scanned_at + offset_seconds
   e. Check for conflicts:
      ├─ Is there an earlier scan for same ticket?
      │  YES → conflict: double_entry (critical alert)
      │  NO  → conflict: false
      └─ Is there a later scan?
         YES → conflict: duplicate_scan (log)
         NO  → conflict: false
   f. Store Scan record in database

4. Return successfully processed scan_ids to device
5. Device removes synced scans from pending queue
```

### 5.2 Conflict Detection Matrix

```
Previous scans for ticket?
├─ NO → result: FIRST_SCAN, severity: INFO

└─ YES
   ├─ New scan earlier than earliest existing?
   │  YES → conflict: DOUBLE_ENTRY
   │       severity: CRITICAL
   │       action: Security alert + manual review
   │
   └─ NO
      ├─ New scan later than latest existing?
      │  YES → conflict: DUPLICATE_SCAN
      │       severity: LOW
      │       action: Log + audit trail
      │
      └─ NO (impossible - must be before or after)
```

---

## 6. Ash Resources & Domain

### 6.1 Domain: Scanning

```elixir
defmodule VoelgoedEvents.Scanning do
  use Ash.Domain,
    extensions: [AshJsonApi.Domain]

  resources do
    resource VoelgoedEvents.Ash.Resources.Scanning.Device
    resource VoelgoedEvents.Ash.Resources.Scanning.Scan
    resource VoelgoedEvents.Ash.Resources.Scanning.Gate
    resource VoelgoedEvents.Ash.Resources.Scanning.SyncBatch
  end
end
```

### 6.2 Key Resource Attributes

**Device Resource:**
- `id`: UUID (primary key)
- `organization_id`: Tenancy
- `name`: Device display name
- `device_type`: :ipad | :phone | :desktop
- `api_key`: Bearer token (unique, sensitive)
- `is_paired`: Boolean (authorization flag)
- `last_sync_at`: Timestamp of last successful sync
- `deleted_at`: Soft delete timestamp

**Scan Resource:**
- `id`: UUID
- `scan_id`: UUID (idempotency key - globally unique)
- `ticket_id`: Foreign key
- `device_id`: Foreign key
- `scanned_at`: Device-reported timestamp
- `scanned_at_canonical`: After offset correction
- `gate_id`: Which gate
- `outcome`: :valid | :duplicate | :invalid | :gate_access_denied | :expired
- `conflict`: Boolean
- `conflict_reason`: :double_entry | :duplicate_scan | nil
- `created_at`: Server timestamp

**Gate Resource:**
- `id`: UUID
- `event_id`: Which event
- `name`: Display name
- `allowed_zones`: Array of zone strings
- `capacity`: Max concurrent entries

**SyncBatch Resource:**
- `batch_id`: UUID (idempotency key - globally unique)
- `device_id`: Which device
- `processed_scan_ids`: Array of successfully processed scan UUIDs
- `offset_seconds`: Clock correction applied

---

## 7. Security & Anti-Spoofing

### 7.1 Attack Vector: Forged Manifest

**Threat:** Attacker swaps in fake ticket list  
**Defense:** HMAC signature + device API key verification

### 7.2 Attack Vector: Fake Scans

**Threat:** Attacker invents scans that never happened  
**Defense:** Scan signature + timestamp validation

### 7.3 Attack Vector: Replay Attack

**Threat:** Attacker replays old scan multiple times  
**Defense:** scan_id idempotency + batch_id deduplication

### 7.4 Attack Vector: Double-Entry

**Threat:** Two devices scan same ticket at same time  
**Defense:** Canonical timestamp comparison (earliest wins)

### 7.5 Attack Vector: Clock Manipulation

**Threat:** Device lies about scan time  
**Defense:** Server offset correction + comparison of all scans

### 7.6 Rate Limiting

Protect sync endpoint from DDoS:
- Max 10 syncs per minute per device
- Fail fast with 429 Too Many Requests
- Uses Redis with key expiry for state

---

## 8. Device Pairing & Authorization

### 8.1 Pairing Flow

**Admin QR Code Scan:**

1. Device displays QR code with pairing token (5 min expiry)
2. Admin scans QR code
3. POST /api/scanning/pair { pairing_token, device_id }
4. Server verifies token (Redis lookup, single-use)
5. Server creates Device record, generates api_key
6. Returns: { device_id, api_key, organization_id }
7. Device stores api_key in localStorage + secure storage
8. Device is now authorized to download manifests and sync

### 8.2 Device Revocation

**If device lost/stolen:**

1. Admin: DELETE /api/scanning/devices/:id
2. Device is soft-deleted (deleted_at set)
3. API key is invalidated immediately
4. Any pending syncs from that device flagged as unverified
5. Manual review required for conflicting scans

---

## 9. Conflict Resolution Matrices

### 9.1 Scan Outcome Determination

```
Input: barcode_hash, gate_id, ticket state, local scan log

Barcode in manifest?
├─ NO → outcome: INVALID, display: RED

└─ YES
   ├─ Gate allowed?
   │  ├─ NO → outcome: GATE_ACCESS_DENIED, display: RED
   │  └─ YES
   │     ├─ Already scanned (entry_limit)?
   │     │  ├─ YES → outcome: DUPLICATE, display: RED
   │     │  └─ NO
   │     │     ├─ Ticket expired?
   │     │     │  ├─ YES → outcome: EXPIRED, display: RED
   │     │     │  └─ NO → outcome: VALID, display: GREEN
```

### 9.2 Conflict Detection (After Sync)

```
Previous scans for ticket?
├─ NO → result: FIRST_SCAN, severity: INFO

└─ YES
   ├─ New scan earlier than earliest existing?
   │  YES → conflict: DOUBLE_ENTRY (critical alert)
   │
   └─ NO
      ├─ New scan later than latest existing?
      │  YES → conflict: DUPLICATE_SCAN (low severity)
```

---

## 10. Observability & Telemetry

### 10.1 Telemetry Events

- **manifest.download**: Device downloads manifest
- **manifest.verified**: Device verifies signature
- **scan.local**: Local offline scan (device-side analytics)
- **scan.valid**: Local validation passed
- **scan.invalid**: Local validation failed
- **sync.attempt**: Device attempts to sync batch
- **sync.success**: Sync completed, scans processed
- **sync.failed**: Sync failed (will retry)
- **conflict.detected**: Double-entry or duplicate detected
- **device.paired**: Device authorized
- **device.revoked**: Device deauthorized

### 10.2 Key Metrics

| Metric | Query | Alert Threshold |
|--------|-------|---|
| **Scan Rate** | rate(voelgoedevents_scanning_scans_total[1m]) | Expected: 100-200/min |
| **Conflict Rate** | rate(voelgoedevents_scanning_conflicts_total[5m]) | >10/min (investigate) |
| **Sync Success Rate** | success/total | <99% (alert) |
| **Pending Sync Queue** | sum(voelgoedevents_scanning_pending_syncs) | >1000 items (alert) |
| **Scan Latency (p95)** | histogram_quantile(0.95, ...) | <200ms |

---

## 11. Implementation Guide

### 11.1 Phase-by-Phase Checklist

**Phase 1: Infrastructure (Week 1)**
- [ ] Ash Resources created (Device, Scan, Gate, SyncBatch)
- [ ] Domain `Scanning` configured
- [ ] PostgreSQL schema migrated
- [ ] HMAC signing/verification functions tested

**Phase 2: Manifest Hydration (Week 2)**
- [ ] Endpoint GET /api/scanning/events/:id/manifest
- [ ] Manifest signature generation (server)
- [ ] Client-side Svelte hydration logic
- [ ] IndexedDB storage & queries validated
- [ ] Offline validation tree implemented

**Phase 3: Offline Scanning (Week 2-3)**
- [ ] Local scan log store (IndexedDB)
- [ ] Decision tree logic fully tested
- [ ] UI components (Green/Red indicators)
- [ ] Latency benchmarked (<200ms)

**Phase 4: Sync Protocol (Week 3-4)**
- [ ] Sync batching (50 items/request) implemented
- [ ] Scan signature generation (client) tested
- [ ] Sync retry with exponential backoff
- [ ] Server-side conflict detection
- [ ] Idempotency verified

**Phase 5: Security (Week 4)**
- [ ] Device pairing flow (QR code)
- [ ] API key rotation tested
- [ ] Rate limiting on sync endpoint
- [ ] Security tests (forged manifests, fake scans)

**Phase 6: Observability (Week 4)**
- [ ] All telemetry events emitted
- [ ] Prometheus scraping configured
- [ ] Grafana dashboard created
- [ ] Alerts tuned and tested

**Phase 7: Load Testing (Week 5)**
- [ ] 50 concurrent devices
- [ ] 20,000+ tickets in manifest
- [ ] Sync batches at 100/sec
- [ ] Conflict detection under load
- [ ] Chaos scenarios (network failures, clock drift)

---

## 12. Testing & Chaos Scenarios

### 12.1 Scenarios to Test

1. **Complete Flow**: Manifest download → Local scans → Sync → Conflict detection
2. **Double-Entry**: Earlier scan arrives in later sync batch
3. **Clock Drift**: Device clock 15s off, offset corrects it
4. **Network Failure**: Partial batch upload, retry succeeds
5. **Manifest Expiry**: Device re-hydrates on new version
6. **Device Loss**: Revoke device, scans flagged as unverified
7. **Mass Resync**: 50 devices syncing after server outage

---

## 13. Disaster Recovery

### 13.1 Lost/Stolen Device

```
1. Admin: DELETE /api/scanning/devices/:id
2. Device soft-deleted, api_key invalidated
3. Pending syncs from that device: flagged
4. Manual review for conflicting scans
```

### 13.2 Manifest Becomes Stale

```
1. Event manifest_version incremented
2. Devices check version periodically
3. If stale: Prompt "New tickets available?"
4. Device downloads new manifest, verifies signature
```

### 13.3 Mass Resync After Server Outage

```
Queue management:
- Rate limit to 10 sync requests/min/device
- Devices queue pending scans in IndexedDB
- Exponential backoff prevents thundering herd
- Gradual recovery with database load balancing
```

---

## Quick Reference

### API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------| 
| GET | `/api/scanning/events/:id/manifest` | Download signed manifest |
| POST | `/api/scanning/sync` | Upload batched scans |
| POST | `/api/scanning/pair` | Pair device (QR code) |
| DELETE | `/api/scanning/devices/:id` | Revoke device |

### Key Concepts

| Concept | Definition |
|---------|-----------|
| **Hydration** | Device downloads manifest before gates open |
| **Manifest** | List of valid ticket hashes + gate rules (signed) |
| **Offset** | Clock correction (server_time - device_time) |
| **Scan** | Record of one barcode scanned by one device |
| **Conflict** | Multiple scans of same ticket |
| **Idempotency** | Same scan_id processed once |

---

**End of Document**

*For updates, contact Mobile & Distributed Systems team.*

*Last Updated: 2025-12-07*  
*Status: Production-Ready*  
*Compliance: Zero forgeries, offline-first, deterministic conflict resolution*
