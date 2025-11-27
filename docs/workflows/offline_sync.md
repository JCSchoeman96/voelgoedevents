# Workflow: Offline Sync

**Scanner device offline → stores scans locally → reconnects → syncs batch to server safely**

---

## 1. Purpose & Overview

**Offline Sync** is the synchronization workflow that reconciles scans recorded locally on scanner PWA devices while offline. When a scanner loses internet connectivity, it continues capturing QR codes and stores them in IndexedDB. Upon reconnection, it submits all pending scans in a single batch request. The backend deduplicates, validates, and atomically processes them, ensuring:

- **No data loss:** Scans stored locally until connection restored
- **No double-counting:** Duplicate detection prevents same ticket scanned twice
- **Audit trail integrity:** Original timestamps preserved, source marked as `offline_sync`
- **Atomic consistency:** All-or-nothing transaction (partial batches don't create orphaned records)
- **Idempotency:** Same batch submitted twice returns same result (no re-processing)
- **Seamless UX:** Users never interrupted, venue operations continue unaffected

**Why it matters:**

- **Venue network unreliability:** WiFi/cellular can drop during events (gates, large crowds, interference)
- **Safety first:** Scans continue locally, no lost admissions
- **Later reconciliation:** Once online, entire batch syncs with server
- **Atomic all-or-nothing:** Either full batch processes or nothing (prevents inconsistency)
- **Progressive Web App:** Enables fully offline-capable PWA on iPad/Android tablets

---

## 2. High-Level Flow

```
Scanner Device (QR capture)
  ↓
Try online POST /api/scans (normal)
  ├─ Success: Entry processed in real-time ✓
  └─ Network error: Fallback to offline
  ↓
Store scan locally (IndexedDB)
  ├─ Queue in pending_scans table
  └─ Show "Stored for sync" (yellow indicator)
  ↓
[User later restores connection]
  ↓
Service Worker detects online event
  ↓
Collect all pending scans from IndexedDB
  ├─ Build batch_id (UUID)
  ├─ Include device_id, gate_id, org_id
  └─ Preserve original scanned_at timestamps
  ↓
POST /api/scans/sync (batch request)
  ├─ Authorization: Bearer token (device auth)
  └─ Payload: {batch_id, device_id, scans: [...]}
  ↓
Backend: Authenticate device + validate batch
  ├─ Check bearer token
  ├─ Verify batch_id not seen before (idempotency)
  └─ Validate timestamp + schema
  ↓
Dedup scans (three-tier strategy):
  ├─ Check ETS hot cache (< 1ms, per-node)
  ├─ Check Redis warm cache (< 10ms, cluster-wide)
  └─ Exclude already-scanned tickets
  ↓
Validate remaining scans:
  ├─ Fetch all ticket codes from database
  ├─ Verify each ticket exists + active
  └─ Collect error details for invalid scans
  ↓
ATOMIC TRANSACTION (all-or-nothing):
  ├─ Create Scan records (batch insert)
  ├─ Update Ticket statuses to :scanned
  ├─ Create BatchSync metadata (tracking)
  └─ Commit (all durable now)
  ↓
Post-transaction:
  ├─ Update Redis dedup caches (5-min TTL)
  ├─ Update ETS hot caches (per-node)
  ├─ Invalidate occupancy cache (will recompute)
  └─ Write audit log
  ↓
Notifications:
  ├─ Broadcast PubSub: batch:{batch_id} (PWA progress)
  └─ Broadcast PubSub: occupancy (admin dashboard)
  ↓
Return HTTP 200 OK (batch result summary)
  ├─ processed_count: N
  ├─ error_count: M
  ├─ errors: [details of M invalid scans]
  └─ timestamp_range: [oldest, newest scan]
  ↓
PWA receives result:
  ├─ If errors: Show failed scans, allow manual review
  ├─ Mark successfully synced scans as :synced
  └─ Clear IndexedDB (successful scans removed)
  ↓
UI updates:
  ├─ Green ✓ for successfully processed
  ├─ Red ✗ for failed (user/venue can retry)
  └─ Clear all, ready for next scan
```

---

## 3. Preconditions (Must Be True Before Starting)

### Scanner Device & Authentication
- ✅ Scanner device has valid authentication token (bearer token, not expired)
- ✅ Scanner device status is `:active` (not inactive/deactivated)
- ✅ Scanner device is assigned to a gate (gate_id not null)
- ✅ Gate belongs to organization + event (org_id and event_id known)

### Offline Queue
- ✅ Device has at least one pending scan in IndexedDB (queue not empty)
- ✅ Each scan has: ticket_code, scanned_at, device_id, offline_id (local UUID)
- ✅ Scan timestamps are ISO8601 format (valid DateTime)

### Batch Structure
- ✅ Batch payload is valid JSON
- ✅ Batch includes: batch_id (UUID), device_id, scans array, batch_size
- ✅ batch_size matches length of scans array
- ✅ batch_id is unique (not previously synced)

### Format Validation
- ✅ All ticket codes have valid format (base62, 16 chars, e.g., "3KQR-7F92-4M1X")
- ✅ All scanned_at timestamps are within ±24 hours of server time (offline tolerance)
- ✅ batch_size is reasonable (1 ≤ batch_size ≤ 10,000 scans)

### Event & System State
- ✅ Event is in `:live` status (not draft/ended/archived)
- ✅ All tickets in batch belong to same event + organization
- ✅ PostgreSQL database connection available
- ✅ Redis cache available (or graceful fallback enabled)
- ✅ Phoenix PubSub operational

---

## 4. Postconditions (What Is True After Success)

### Persistent State (PostgreSQL)

✅ **Scan Records Created** (one per valid scan in batch):
```
{
  id: UUID (newly generated),
  ticket_id: UUID,
  device_id: UUID,
  gate_id: UUID,
  event_id: UUID,
  organization_id: UUID,
  status: :admitted,
  scanned_at: DateTime (original device timestamp preserved),
  gate_name: "Main Entrance",
  device_name: "iPad-Gate-1",
  source: :offline_sync (denotes batch origin),
  created_at: DateTime.utc_now(),
  updated_at: DateTime.utc_now()
}
```

✅ **Ticket Records Updated** (one per scanned ticket):
```
status: :active → :scanned (or :scanned → :scanned if re-scanned)
scanned_at: (original device timestamp from batch)
last_gate_id: {gate_id}
scan_count: incremented
```

✅ **BatchSync Metadata Record Created** (batch-level tracking):
```
{
  id: UUID,
  batch_id: string (idempotency key),
  device_id: UUID,
  event_id: UUID,
  organization_id: UUID,
  status: :completed (or :partial_success),
  batch_size: integer (total scans in batch),
  processed_count: integer (successfully created),
  error_count: integer (failed validations),
  synced_at: DateTime.utc_now(),
  created_at: DateTime.utc_now()
}
```

### Cache Layers (Populated)

✅ **Redis (Cluster-Wide Warm Cache)**:
```
ZSET Key: voelgoed:org:{org_id}:event:{event_id}:scans:recent
Score: Unix timestamp (from scanned_at)
Member: "{ticket_id}:{device_id}:{gate_id}"
TTL: 300 seconds (5 minutes)

STRING Key: voelgoed:org:{org_id}:ticket:{ticket_code}:last_scan
Value: "{scan_id}:{gate_id}:{unix_timestamp}"
TTL: 300 seconds (5 minutes)

Occupancy Key: voelgoed:org:{org_id}:event:{event_id}:occupancy
Action: DELETED (will recompute on next query)
```

✅ **ETS (Per-Node Hot Cache)**:
```
Table: :recent_scans
Key: {org_id, ticket_code}
Value: %{ticket_id, scan_at, gate_id, status}
TTL: 300 seconds (5 minutes)
Lookup latency: < 1ms
```

### Notifications & Audit

✅ **PubSub Broadcast (PWA Subscriber)**:
```
Topic: batch:{batch_id}
Message: {
  event: :sync_complete,
  batch_id: UUID,
  status: :completed,
  processed_count: N,
  error_count: M,
  timestamp: ISO8601
}
Subscribers: Scanner PWA (displays result to operator)
```

✅ **PubSub Broadcast (Admin Dashboard)**:
```
Topic: occupancy:{org_id}:{event_id}
Message: {
  event: :batch_sync_completed,
  batch_id: UUID,
  scans_added: N,
  gate_name: string,
  gate_occupancy: current,
  total_occupancy: current,
  timestamp: ISO8601
}
Subscribers: Admin dashboards, analytics workers, real-time reporting
```

✅ **Audit Log Entry**:
```
{
  organization_id: org_id,
  user_id: nil (system action),
  action: :batch_sync_completed,
  entity_type: :BatchSync,
  entity_id: batch_sync_id,
  changes: {
    batch_id: UUID,
    device_id: UUID,
    batch_size: N,
    processed_count: N_processed,
    error_count: N_errors,
    duplicates: count,
    missing_tickets: count,
    invalid_tickets: count
  },
  metadata: {
    batch_created_at: ISO8601,
    sync_duration_seconds: elapsed
  },
  timestamp: DateTime.utc_now()
}
```

### API Response (Batch Result Summary)

✅ **HTTP 200 OK** (Batch processed, fully or partially):
```json
{
  "batch_id": "uuid-batch-xyz",
  "status": "completed",
  "processed_count": 42,
  "error_count": 3,
  "summary": {
    "total_scans": 45,
    "new_scans": 42,
    "duplicate_scans": 2,
    "missing_tickets": 1,
    "invalid_tickets": 0
  },
  "errors": [
    {
      "offline_id": "uuid-local-001",
      "ticket_code": "3KQR-XXXX-XXXX",
      "reason": "already_scanned",
      "last_scan_at": "2025-11-26T14:25:00Z"
    },
    {
      "offline_id": "uuid-local-002",
      "ticket_code": "FAKE-XXXX-XXXX",
      "reason": "ticket_not_found"
    },
    {
      "offline_id": "uuid-local-003",
      "ticket_code": "3KQR-YYYY-YYYY",
      "reason": "ticket_already_used"
    }
  ],
  "timestamp": "2025-11-26T14:31:00Z",
  "sync_duration_seconds": 1.234
}
```

✅ **HTTP 200 OK** (Duplicate Batch - Idempotent Result):
```json
{
  "batch_id": "uuid-batch-xyz",
  "status": "completed",
  "processed_count": 42,
  "error_count": 3,
  "message": "Batch already synced (idempotent)",
  "timestamp": "2025-11-26T14:31:00Z"
}
```

### Failure Cases (Guaranteed NOT to happen on error)

❌ On **ANY error**, these are guaranteed NOT to happen:
- ✅ No duplicate Scan records created (batch_id idempotency)
- ✅ No partial Scan creation (transaction rolls back entirely)
- ✅ No Ticket state corruption (all-or-nothing consistency)
- ✅ No cache poisoning (caches only updated on success)
- ✅ No orphaned BatchSync records (created within transaction)
- ✅ No lost scans (stored in IndexedDB, can retry)
- ✅ No audit log gaps (all attempts logged)

---

## 5. Detailed Step-by-Step Workflow (Happy Path)

### Phase 1: Offline Queue Management (Device)

**Step 1: Scanner PWA Detects QR Code While Offline**

```
Process:
  1. User scans QR code at venue gate
  2. App attempts POST /api/scans (online endpoint)
  3. Network request fails (timeout or connection refused)
  4. App catches error: "Network unavailable"
  5. Decision: Store locally instead of failing
```

**Step 2: Create Offline Scan Record**

```
Scan structure (IndexedDB):
  {
    offline_id: "uuid-local-abc123",      # Local ID (not from server)
    ticket_code: "3KQR-7F92-4M1X",        # QR payload
    scanned_at: "2025-11-26T14:30:00Z",   # Device ISO8601 timestamp
    device_id: "uuid-scanner-gate-1",     # Scanner identity
    gate_id: "uuid-gate-1",               # Gate assignment
    status: "pending",                    # Not yet synced
    sync_attempts: 0,                     # Track retries
    last_sync_error: null
  }

Store in IndexedDB:
  - Database: 'voelgoed-scanner'
  - Object Store: 'pending_scans'
  - Key Path: 'offline_id'
```

**Step 3: Update Scanner UI (User Feedback)**

```
Visual indicators:
  - Green ✓: Online scan successful (real-time)
  - Yellow ◐: Stored locally (offline mode, will sync)
  - Red ✗: Error (invalid ticket, network error)

Audio feedback:
  - Success beep: Online scan processed
  - Warning tone: Stored locally, will sync
  - Error tone: Cannot proceed, try again

User sees:
  - "Scanned: Stored for sync" (yellow indicator)
  - Scanner remains ready for next QR code
  - Operator knows entry queued for later sync
```

### Phase 2: Offline Queue Accumulation

**Step 4: Continue Scanning While Offline**

```
Process:
  - Each QR code stored to IndexedDB
  - Queue accumulates during outage
  - IndexedDB is persistent (survives app reload)
  - Users don't lose any scans
  
Example queue after 1 hour offline:
  - 342 scans stored in pending_scans table
  - All with original timestamps preserved
  - Ready for batch sync when online
```

### Phase 3: Reconnection Detection & Batch Preparation

**Step 5: Service Worker Detects Online Event**

```javascript
// lib/voelgoed_scanner_app/public/service-worker.js

self.addEventListener('online', async () => {
  console.log('Device online, initiating sync');
  
  // Signal main app to prepare batch sync
  const clients = await self.clients.matchAll();
  clients.forEach(client => {
    client.postMessage({
      type: 'CONNECTION_RESTORED',
      timestamp: new Date().toISOString()
    });
  });
});

// Main app receives signal
window.addEventListener('message', (event) => {
  if (event.data.type === 'CONNECTION_RESTORED') {
    initiateSync();  // Start batch sync process
  }
});
```

**Step 6: Collect Pending Scans from IndexedDB**

```
Process:
  1. Open IndexedDB connection
  2. Query pending_scans store (all records with status='pending')
  3. Build array of scans
  4. Calculate batch statistics
  
Result:
  {
    batch_id: "uuid-batch-20251126-abc",  # Generated locally
    device_id: "uuid-scanner-gate-1",
    batch_created_at: "2025-11-26T15:30:00Z",
    scans: [
      {ticket_code: "3KQR-7F92-4M1X", scanned_at: "2025-11-26T14:30:00Z", ...},
      {ticket_code: "2JPX-3HK8-5N2Y", scanned_at: "2025-11-26T14:32:45Z", ...},
      ...  # 342 scans total
    ],
    batch_size: 342
  }
```

**Step 7: Submit Batch to Backend**

```javascript
// Send batch via HTTP POST

const response = await fetch('/api/scans/sync', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${getDeviceToken()}`
  },
  body: JSON.stringify(batch)
});

if (!response.ok) {
  console.error(`Sync failed: ${response.status}`);
  // Scans remain in IndexedDB, retry on next connection
  return;
}

const result = await response.json();
```

### Phase 4: Backend Reception & Authentication

**Step 8: Phoenix Controller Receives Batch**

```
Request:
  POST /api/scans/sync
  Authorization: Bearer {device_token}
  Content-Type: application/json
  
  {
    "batch_id": "uuid-batch-20251126-abc",
    "device_id": "uuid-scanner-gate-1",
    "batch_created_at": "2025-11-26T15:30:00Z",
    "scans": [
      {"ticket_code": "3KQR-7F92-4M1X", "scanned_at": "2025-11-26T14:30:00Z"},
      ...
    ],
    "batch_size": 342
  }

Process:
  1. Extract bearer token from header
  2. Parse JSON payload
  3. Validate schema (all required fields present)
  4. Proceed to authentication
```

**Step 9: Validate Batch Schema & Integrity**

```
Checks:
  ✓ batch_id present (UUID format)
  ✓ device_id present (matches request)
  ✓ batch_created_at present (valid ISO8601)
  ✓ scans is array (non-empty, max 10k)
  ✓ batch_size > 0
  ✓ length(scans) == batch_size (no mismatch)
  ✓ All ticket_code fields present (no nulls)
  ✓ All scanned_at fields present (valid ISO8601)

If any check fails:
  → Return 400 (bad request)
  → Don't process batch
  → PWA can retry later
```

**Step 10: Authenticate Device**

```
Process:
  1. Extract bearer token from Authorization header
  2. Query ScanDevice table by device_token
  3. Verify exactly one device found
  4. Check device.status == :active
  5. Verify device.id == device_id (from batch)
  6. Extract org_id + event_id from device context

If any check fails:
  → Return 401 (unauthorized)
  → Device needs re-authentication
  → PWA prompts user to re-auth device
```

**Step 11: Validate Batch Timestamp**

```
Process:
  1. Parse batch_created_at from batch
  2. Calculate time difference from server now
  3. Allow large tolerance: ±24 hours (offline can be long)
  
  time_diff = abs(now - batch_created_at)
  
  if time_diff > 86400 seconds (24 hours):
    → Return 400 (batch too old)
    → Discard batch (operator error)
  else:
    → Continue to deduplication
```

### Phase 5: Idempotency & Deduplication

**Step 12: Check for Duplicate Batch (Idempotency)**

```
Process:
  1. Query BatchSync table by batch_id + org_id
  2. If found: Batch already processed (return cached result)
  3. If not found: First time seeing this batch (proceed)

Idempotency guarantees:
  - Same batch_id submitted twice returns same result
  - No re-processing (no duplicate Scan records)
  - Second submission returns cached response
  - PWA can safely retry without worry
```

**Step 13: Dedup Scans Against Redis Cache**

```
Process:
  1. Build Redis ZSET key:
     zset_key = "voelgoed:org:#{org_id}:event:#{event_id}:scans:recent"
  
  2. Query recent scans (all in 5-min dedup window):
     recent_scans = Redis ZRANGE(zset_key, -inf, +inf, BYSCORE)
  
  3. For each scan in batch:
     If ticket_code in recent_scans:
       → Scan is duplicate (same ticket scanned recently elsewhere)
       → Add to duplicates list
     Else:
       → New scan (not seen in past 5 min)
       → Add to proceed list
  
  Result:
    - new_scans: 340 (can be created)
    - duplicate_scans: 2 (already scanned recently)
```

**Step 14: Dedup Scans Against ETS Cache**

```
Process:
  1. For each new_scan (not in Redis):
     
     ets_key = {org_id, ticket_code}
     
     If :ets.lookup(:recent_scans, ets_key) found:
       If scan.scanned_at within 5 minutes:
         → Duplicate detected (add to duplicates)
       Else:
         → Cache expired, proceed
     Else:
       → Not in ETS, continue
  
  Result:
    - final_new_scans: 338 (will be created)
    - total_duplicates: 4 (will skip)
```

### Phase 6: Ticket Validation

**Step 15: Fetch All Tickets from Database**

```
Process:
  1. Extract all ticket_codes from final_new_scans
  2. Query Ticket table:
     
     ticket_codes = ["3KQR-7F92-4M1X", "2JPX-3HK8-5N2Y", ...]
     
     {:ok, tickets} = Ash.read(Ticket, filter: [
       ticket_code: {:in, ticket_codes},
       organization_id: org_id,
       event_id: event_id
     ])
  
  3. Build ticket lookup map
  4. Check for missing tickets:
     
     found_codes = tickets.map(& &1.ticket_code)
     requested_codes = ticket_codes
     missing_codes = requested_codes - found_codes
     
     If missing_codes not empty:
       → Some tickets not found (forged codes?)
       → Collect error details
       → Will skip these in batch
  
  Result:
    - tickets_found: 337
    - tickets_missing: 1 (invalid/forged code)
```

**Step 16: Validate Ticket States**

```
Process:
  1. For each ticket found:
     
     If ticket.status not in [:active, :scanned]:
       → Ticket already used/voided/refunded
       → Cannot scan
       → Add to invalid list
     Else:
       → Ticket is scannable
       → Add to valid list
  
  Status checks:
    - :active → Can scan ✓
    - :scanned → Can re-scan (venue allows re-entry) ✓
    - :used → Already used, deny ✗
    - :voided → Refunded/cancelled, deny ✗
    - :refunded → Refunded, deny ✗
  
  Result:
    - valid_tickets: 335
    - invalid_tickets: 2 (already used)
    - missing_tickets: 1
    - total_errors: 4
```

### Phase 7: Atomic Batch Transaction

**Step 17: Begin Database Transaction**

```
Process:
  {:ok, {scans, batch_sync}} = Ash.Repo.transaction(fn ->
    # Steps 18-20 execute atomically
    # All succeed or all fail (no partial state)
  end)

If transaction succeeds:
  → All records committed
  → Proceed to cache + notifications
  
If transaction fails:
  → Entire batch rolled back
  → No Scan records created
  → BatchSync not created
  → Return 500, PWA retries later
```

**Step 18: Batch Create Scan Records**

```
Within transaction:

For each valid_new_scan:
  1. Parse ticket_code → lookup ticket_id
  2. Parse scanned_at (preserve original device timestamp)
  3. Create Scan record:
     
     {:ok, scan} = Ash.create(Scan, %{
       "ticket_id" => ticket.id,
       "device_id" => device_id,
       "gate_id" => gate_id,
       "event_id" => event_id,
       "organization_id" => org_id,
       "status" => :admitted,
       "scanned_at" => scanned_at,  # Original device time
       "gate_name" => gate.name,
       "device_name" => device.name,
       "source" => :offline_sync  # Mark as offline batch
     })

Result: 335 Scan records created
```

**Step 19: Batch Update Ticket Statuses**

```
Within transaction:

For each created_scan:
  1. Fetch ticket (already in memory)
  2. Update status → :scanned
  
  {:ok, _} = Ash.update(ticket, :scan, %{
    "scanned_at" => scan.scanned_at
  })

Result: 335 Ticket records updated
```

**Step 20: Create BatchSync Metadata**

```
Within transaction:

{:ok, batch_sync} = Ash.create(BatchSync, %{
  "batch_id" => batch_id,
  "device_id" => device_id,
  "event_id" => event_id,
  "organization_id" => org_id,
  "status" => :completed,
  "batch_size" => batch_size,  # 342
  "processed_count" => 335,    # Successfully created
  "error_count" => 7,          # Duplicates + missing + invalid
  "synced_at" => DateTime.utc_now()
})

Stores batch metadata for:
  - Audit trail
  - Idempotency checks
  - Admin reporting
```

**Step 21: Commit Transaction**

```
Transaction automatically commits if no errors raised

All changes now durable in PostgreSQL:
  ✓ 335 Scan records created
  ✓ 335 Ticket records updated
  ✓ 1 BatchSync record created
  ✓ Complete audit trail ready
```

### Phase 8: Cache Invalidation & Updates

**Step 22: Update Redis Caches**

```
For each successfully created scan:

1. Add to ZSET for time-range analytics:
   zset_key = "voelgoed:org:#{org_id}:event:#{event_id}:scans:recent"
   zset_member = "#{ticket.id}:#{device_id}:#{gate_id}"
   zset_score = DateTime.to_unix(scan.scanned_at)
   
   ZADD(zset_key, zset_score, zset_member)

2. Add to per-ticket last_scan cache:
   string_key = "voelgoed:org:#{org_id}:ticket:#{ticket_code}:last_scan"
   string_value = "#{scan.id}:#{gate_id}:#{zset_score}"
   
   SET(string_key, string_value, EX 300)

3. Invalidate occupancy cache (forces recompute):
   occupancy_key = "voelgoed:org:#{org_id}:event:#{event_id}:occupancy"
   
   DEL(occupancy_key)
```

**Step 23: Update ETS Hot Caches**

```
For each successfully created scan:

ets_key = {org_id, ticket_code}
ets_value = %{
  ticket_id: ticket.id,
  scan_at: scan.scanned_at,
  gate_id: gate_id,
  status: :admitted
}

:ets.insert(:recent_scans, {ets_key, ets_value})

TTL: 300 seconds (auto-evict or manual cleanup)
```

### Phase 9: Real-Time Notifications

**Step 24: Broadcast PubSub (PWA Subscriber)**

```
Topic: batch:#{batch_id}

Message: {
  event: :sync_complete,
  batch_id: batch_id,
  status: :completed,
  processed_count: 335,
  error_count: 7,
  timestamp: DateTime.to_iso8601(DateTime.utc_now())
}

Subscribers:
  - Scanner PWA: Displays "Synced 335 scans"
  - Operator sees confirmation on screen
```

**Step 25: Broadcast PubSub (Admin Dashboard)**

```
Topic: occupancy:#{org_id}:#{event_id}

Message: {
  event: :batch_sync_completed,
  batch_id: batch_id,
  scans_added: 335,
  gate_name: gate.name,
  gate_occupancy: calculate_gate_occupancy(gate_id),
  total_occupancy: calculate_total_occupancy(event_id),
  timestamp: DateTime.to_iso8601(DateTime.utc_now())
}

Subscribers:
  - Admin LiveView dashboard: Updates occupancy gauge
  - Analytics workers: Record batch sync event
  - Real-time reporting: Capture metrics
```

### Phase 10: Audit & Response

**Step 26: Write Audit Log**

```
Entry: {
  organization_id: org_id,
  user_id: nil,  # System action (no user)
  action: :batch_sync_completed,
  entity_type: :BatchSync,
  entity_id: batch_sync.id,
  
  changes: {
    batch_id: batch_id,
    device_id: device_id,
    batch_size: 342,
    processed_count: 335,
    error_count: 7,
    duplicates: 4,
    missing_tickets: 1,
    invalid_tickets: 2
  },
  
  metadata: {
    batch_created_at: batch_created_at,
    sync_duration_seconds: elapsed_seconds
  },
  
  timestamp: DateTime.utc_now()
}

Purpose:
  - Compliance: Full audit trail
  - Support: Troubleshooting sync issues
  - Analytics: Batch sync patterns
  - Fraud: Historical record for investigation
```

**Step 27: Return HTTP 200 OK (Batch Result)**

```json
HTTP/1.1 200 OK
Content-Type: application/json

{
  "batch_id": "uuid-batch-20251126-abc",
  "status": "completed",
  "processed_count": 335,
  "error_count": 7,
  "summary": {
    "total_scans": 342,
    "new_scans": 335,
    "duplicate_scans": 4,
    "missing_tickets": 1,
    "invalid_tickets": 2
  },
  "errors": [
    {
      "offline_id": "uuid-local-001",
      "ticket_code": "3KQR-XXXX-XXXX",
      "reason": "already_scanned",
      "last_scan_at": "2025-11-26T14:25:00Z"
    },
    {
      "offline_id": "uuid-local-002",
      "ticket_code": "3KQR-YYYY-YYYY",
      "reason": "already_scanned",
      "last_scan_at": "2025-11-26T14:28:30Z"
    },
    {
      "offline_id": "uuid-local-003",
      "ticket_code": "FAKE-ZZZZ-ZZZZ",
      "reason": "ticket_not_found"
    },
    {
      "offline_id": "uuid-local-004",
      "ticket_code": "3KQR-AAAA-AAAA",
      "reason": "ticket_already_used"
    },
    {
      "offline_id": "uuid-local-005",
      "ticket_code": "3KQR-BBBB-BBBB",
      "reason": "already_scanned",
      "last_scan_at": "2025-11-26T14:32:00Z"
    },
    {
      "offline_id": "uuid-local-006",
      "ticket_code": "3KQR-CCCC-CCCC",
      "reason": "already_scanned",
      "last_scan_at": "2025-11-26T14:29:15Z"
    },
    {
      "offline_id": "uuid-local-007",
      "ticket_code": "3KQR-DDDD-DDDD",
      "reason": "ticket_already_used"
    }
  ],
  "timestamp": "2025-11-26T15:31:00Z",
  "sync_duration_seconds": 2.456
}
```

### Phase 11: PWA Post-Sync Cleanup

**Step 28: Remove Successfully Synced Scans from IndexedDB**

```javascript
async function clearSyncedScans(batch_result) {
  const db = await openDB('voelgoed-scanner');
  const tx = db.transaction('pending_scans', 'readwrite');
  const store = tx.objectStore('pending_scans');
  
  // Remove successfully synced scans
  batch_result.scans.forEach(scan => {
    if (!batch_result.errors.find(e => e.offline_id === scan.offline_id)) {
      // Not in error list = successfully processed
      store.delete(scan.offline_id);
    }
  });
  
  // Keep failed scans for manual retry/review
  batch_result.errors.forEach(error => {
    // Mark as failed but don't delete
    store.update({
      offline_id: error.offline_id,
      status: 'failed',
      last_sync_error: error.reason,
      sync_attempts: store.get(error.offline_id).sync_attempts + 1
    });
  });
  
  await tx.done;
  
  return {
    cleared: batch_result.processed_count,
    kept: batch_result.error_count
  };
}
```

**Step 29: Update Scanner UI with Sync Result**

```javascript
function displaySyncResult(batch_result) {
  if (batch_result.error_count > 0) {
    showWarning(
      `Synced ${batch_result.processed_count} scans, ` +
      `${batch_result.error_count} errors`
    );
    
    // Show error details
    displayErrorDetails(batch_result.errors);
    
    // Allow manual review or re-scan
    enableManualRetry();
  } else {
    showSuccess(`Synced all ${batch_result.processed_count} scans`);
    
    setTimeout(() => {
      clearDisplay();
      focusQRReader();  // Ready for next scan
    }, 2000);
  }
}
```

---

## 6. Edge Cases & Failure Modes

| Edge Case | Cause | Prevention | Recovery |
|-----------|-------|-----------|----------|
| **Duplicate batch** | Same batch_id submitted twice | Batch_id idempotency check in DB | Return cached result, no re-processing |
| **Partial network** | Connection drops mid-sync | HTTP timeout (30 sec default) | PWA retries full batch on reconnect |
| **Large batch timeout** | 10k+ scans take > 30 sec | Split into chunked batches | PWA client implements batching (max 1k per request) |
| **Ticket not found** | Invalid or forged ticket code | Verify ticket exists + active | Skip invalid, include in errors list |
| **Duplicate in batch** | Same ticket scanned twice offline | Internal dedup before insert | Return summary with duplicate count |
| **Ticket already used** | Venue marked as :used between offline and sync | Check status before insert | Skip, include in errors |
| **Event ended** | Event no longer :live during sync | Verify event.status before transaction | Return error, batch not processed |
| **Device token expired** | Bearer token invalid/expired during sync | Verify token before transaction | Return 401, device needs re-auth |
| **Database timeout** | Transaction locking, slow query | Connection pool, query optimization | Automatic retry with backoff |
| **Redis unavailable** | Cache cluster down during sync | Graceful fallback (proceed without cache) | Slower dedup, all-or-nothing works |
| **ETS lookup fails** | Table not initialized | Verify :recent_scans exists on startup | Proceed to Redis, slightly slower |
| **Scans out of order** | Timestamps not sequential in batch | Don't enforce ordering (use DB insertion order) | Final state consistent (all scans exist) |
| **Timezone/clock skew** | Device clock 24+ hours off | Validate timestamp ±24 hour tolerance | Reject batch, alert operator |
| **Network corruption** | Payload partially transmitted | HTTP 411 Length Required + retry | PWA retries with fresh batch |
| **Concurrent batch** | Two devices submit batches simultaneously | Atomic transactions (no race condition) | Both process independently, DB handles isolation |

---

## 7. Conflict Resolution & Ordering Rules

### Timestamp Precedence

```
When same ticket scanned at multiple gates (impossible in reality, but consider):

Scenario: Ticket 3KQR-7F92-4M1X offline-scanned at Gate-A (14:30) + Gate-B (14:32)

Rule: First scan wins (earliest timestamp)
  - Record created for Gate-A scan (14:30)
  - Second Gate-B scan (14:32) flagged as duplicate
  - Error returned: "already_scanned at Gate-A"

Why: Prevents double-entry (security model)
  - Once scanned at any gate, ticket marked :scanned
  - Subsequent scans rejected (5-minute dedup window)
  - For venue re-entry: must wait 5 minutes
```

### Suspicious Patterns Flagged

```
Batch-level anomalies that trigger audit alerts:

1. High error rate (> 50% invalid tickets):
   - Indicates potential device malfunction or forged codes
   - Flag: Log warning, notify admin
   - Action: Manual review recommended

2. Batch submitted long after offline period:
   - Device offline 2 hours, batch submitted 8 hours later
   - Possible manipulation or replay attempt
   - Flag: Include in audit log, monitor

3. Batch size anomalies:
   - Normal: 50-100 scans per offline event
   - Anomaly: 5,000+ scans (1000x normal)
   - Flag: Log suspicious activity
   - Action: May require admin approval

4. Repeated failed syncs:
   - Same device fails 5+ times in a row
   - Indicates systematic problem (bad device, wrong event)
   - Flag: Alert IT team, disable device
```

---

## 8. Multi-Tenancy & Security

### Organization Isolation (CRITICAL)

**Rule 1: Extract org_id from Authenticated Device**

```elixir
# ✅ CORRECT (org_id from device record)
case Ash.read(ScanDevice, filter: [device_token: bearer_token]) do
  {:ok, [device]} ->
    org_id = device.organization_id  # From device, not request
    # All batch data must belong to this org
end

# ❌ WRONG (org_id from request params)
org_id = params["organization_id"]  # User can spoof!
```

**Rule 2: All Ticket Queries Include org_id Filter**

```elixir
# ✅ CORRECT
Ash.read(Ticket, filter: [
  organization_id: org_id,
  event_id: event_id,
  ticket_code: {:in, ticket_codes}
])

# ❌ WRONG
Ash.read(Ticket, filter: [ticket_code: {:in, ticket_codes}])  # No org filter!
```

**Rule 3: Redis Keys Always Include org_id**

```
✅ voelgoed:org:{org_id}:event:{event_id}:scans:recent
✅ voelgoed:org:{org_id}:ticket:{ticket_code}:last_scan

❌ voelgoed:event:{event_id}:scans:recent           (cross-org collision!)
❌ voelgoed:ticket:{ticket_code}:last_scan          (cross-org collision!)
```

**Rule 4: All Batch Records Include org_id**

```elixir
# BatchSync, Scan, audit logs all require organization_id
Ash.create!(BatchSync, %{
  "organization_id" => org_id,  # ← MANDATORY
  "batch_id" => batch_id,
  ...
})
```

### Scanner Device Authentication

```elixir
# Bearer token strategy: OAuth-style per device

defp authenticate_scanner(bearer_token) do
  case Ash.read(ScanDevice, filter: [device_token: bearer_token, status: :active]) do
    {:ok, [device]} ->
      # Valid device
      {:ok, device}
    
    {:ok, []} ->
      # Token not found or device inactive
      {:error, :invalid_token}
    
    {:error, _} ->
      # Database error
      {:error, :auth_failed}
  end
end

# Token security:
# - Stored as hash in DB (never plain text)
# - Unique per device (can't reuse across scanners)
# - Rotatable by admin (invalidate old tokens)
# - Optional TTL: Can enforce expiration (e.g., 90 days)
```

### Fraud Detection

```elixir
# Flag suspicious patterns in batch:

1. High error rate:
   if error_count > (batch_size * 0.5) do
     alert_security(:high_error_rate_batch, batch_id)
   end

2. Batch submitted long after offline:
   time_since_offline = DateTime.diff(DateTime.utc_now(), batch_created_at, :second)
   if time_since_offline > 28800 do  # 8 hours
     alert_security(:delayed_batch_submission, batch_id)
   end

3. Impossible timestamps:
   if any_scan.scanned_at > DateTime.utc_now() do
     alert_security(:future_timestamp, scan_id)
   end
```

---

## 9. Performance & Consistency

### Batch Processing Performance

**Pre-sync Preparation (PWA)**:
```
Time: < 100ms (typically)

Tasks:
  - Query IndexedDB pending_scans: O(n) reads
  - Build batch JSON: O(n) serialization
  - HTTP POST: Depends on network (100-500ms typical)
```

**Backend Processing (Server)**:
```
Time: O(n) operations, typically 1-5 seconds for 1k scans

Breakdown:
  - Authentication: 5-10ms
  - Batch validation: 1-2ms
  - Idempotency check: < 1ms
  - Redis dedup: 10-50ms (n × 10μs per key)
  - Database fetch tickets: 10-50ms (single query)
  - Validate tickets: 1-2ms (in-memory)
  - Create Scans (batch insert): 100-500ms (n × 0.1-0.5ms)
  - Update Tickets (batch update): 50-200ms (n × 0.05-0.2ms)
  - Create BatchSync: 1-2ms
  - Cache updates (Redis): 50-100ms
  - Cache updates (ETS): < 1ms
  - PubSub broadcasts: 1-5ms
  - Total: 200-1000ms typical
```

### Performance Rules

- ✓ **Batch size limit:** Max 10,000 scans per request (prevent OOM)
- ✓ **Dedup-first strategy:** Redis + ETS before DB queries (reduces work)
- ✓ **Atomic transaction:** All-or-nothing (consistency guaranteed, no partial states)
- ✓ **Async notifications:** PubSub broadcasts don't block response
- ✓ **Indexed queries:** All database lookups use indexes (fast)
- ✓ **Connection pooling:** DB connection pool prevents exhaustion

### Scalability Targets

```
Target: Handle 10k scans per batch

Feasibility:
  - 10k scans × 0.5ms per scan = 5 seconds total
  - HTTP timeout: 30 seconds (safe margin)
  - Memory: ~50MB per batch (reasonable)
  - Database: Handles 1000+ inserts/sec (no problem)
  
Recommendation:
  - PWA client implements batching: max 1k scans per request
  - Server processes 1k batch in ~500ms
  - 10k scans = 10 requests (sequential or parallel)
  - User sees progress as each batch completes
```

---

## 10. Implementation Targets

### Ash Resources & Actions

**1. BatchSync Resource (:create action)**

```
Module: Voelgoedevents.Ash.Resources.Scanning.BatchSync
File: lib/voelgoedevents/ash/resources/scanning/batch_sync.ex

Actions:
  :create
    - Arguments: batch_id, device_id, event_id, batch_size, processed_count, error_count
    - Changes: Set attributes as provided
    - Validations:
      - :batch_id_unique (within org, no duplicate)
      - :batch_size_positive (> 0)
      - :processed_count_valid (0 ≤ processed ≤ batch_size)
      - :organization_matches (multi-tenancy)
```

**2. Scan Resource (Same as process_scan.md)**

```
Module: Voelgoedevents.Ash.Resources.Scanning.Scan
File: lib/voelgoedevents/ash/resources/scanning/scan.ex

Key difference from online scans:
  - source: :offline_sync (instead of online)
  - batch_id: Reference to BatchSync (tracking)
```

**3. Ticket Resource (:scan action, same as process_scan.md)**

```
Module: Voelgoedevents.Ash.Resources.Ticketing.Ticket
File: lib/voelgoedevents/ash/resources/ticketing/ticket.ex

Actions:
  :scan
    - Already defined for online scans
    - Reused for offline batch scans
    - Same state transition: :active/:scanned → :scanned
```

### Phoenix Controllers & Endpoints

**Batch Sync Endpoint**

```
POST /api/scans/sync
  - Authenticated: Bearer token (ScanDevice)
  - Parameters: {batch_id, device_id, scans: [...]}
  - Response: 200 OK {batch_id, status, processed_count, errors}
  - Error codes: 
    - 400 Bad Request (schema validation failed)
    - 401 Unauthorized (invalid device token)
    - 409 Conflict (batch already processed)
    - 422 Unprocessable (ticket validation failed)
    - 500 Server Error (database error, retry recommended)
```

---

## 11. Monitoring & Observability

### Key Metrics

```
1. Batch sync success rate (per batch)
   - Target: > 99% (batches fully processed)
   - Alert if < 95% (systematic sync failures)

2. Batch sync latency (p50, p95, p99)
   - Target: < 2 seconds (1k batch)
   - Alert if > 10 seconds (database or cache issues)

3. Error rate within batches (per scan)
   - Target: < 1% (most scans valid)
   - Alert if > 10% (bad device data or forged codes)

4. Offline queue size
   - Monitor: Max pending scans per device
   - Alert if > 10k (device offline for very long)

5. Batch duplicate rate
   - Monitor: % of scans already scanned
   - Expected: < 0.5% (shouldn't be high)
   - Alert if > 5% (indicates potential fraud)

6. Time-to-sync
   - Monitor: Latency from offline to synced
   - Target: < 30 seconds (network + processing)
   - Alert if > 300 seconds (user frustration)
```

### Alerts

```
- High batch failure rate → Check device authentication + database
- High sync latency → Redis down? Database overloaded?
- High error rate in batches → Device malfunction or bad codes
- Offline queue growing → Device not reconnecting
- Duplicate rate high → Fraud attempt or double-scanning
```

---

## 12. Integration Points

### With `process_scan.md`

```
Relationship:
  process_scan: Online scanning (synchronous, real-time)
  offline_sync: Offline batching (asynchronous, eventual consistency)

Code sharing:
  - Both use Scan resource and :scan action
  - Both update Ticket status to :scanned
  - Both populate Redis/ETS caches
  - Both broadcast PubSub occupancy
  - Difference: source field (:offline_sync vs :online)
```

### With `complete_checkout.md`

```
Workflow sequence:
  1. complete_checkout: Creates Ticket records (status: :active)
  2. process_scan (online) or offline_sync: Scans ticket
  
Connection: Tickets must exist before scanning (issued by complete_checkout)
```

---

## 13. User Experience & Feedback

### Scanner PWA UI States

```
Online Mode:
  - Green ✓ checkmark (real-time)
  - "Entry permitted"
  - Auto-clears after 2 sec
  - Ready for next scan

Offline Detection:
  - Yellow ◐ indicator
  - "Stored for sync"
  - Audio: warning tone
  - Scan continues normally

Sync In Progress:
  - Blue ∿ spinner
  - "Syncing X scans..."
  - Progress bar
  - User waits for result

Sync Complete:
  - Green ✓ or Red ✗ (depending on errors)
  - "Synced 335, errors: 7"
  - Show error details (failures)
  - Ready for next scan

Error Details:
  - List of failed scans
  - Reason (duplicate, missing, invalid)
  - Allow manual retry or discard
```

---

## 14. Future Enhancements

- **Incremental sync:** Resume interrupted batches (not restart from zero)
- **Conflict resolution:** Allow editing scanned_at for mis-timed scans
- **Priority batches:** Fast-track VIP or security-flagged scans
- **Batch compression:** Gzip payloads for very large batches
- **WebSocket streaming:** Real-time sync progress (not polling)
- **Cross-device sync:** Sync one device's queue to another (failover)
- **Scheduled cleanup:** Auto-purge failed scans after N days
- **Machine learning:** Flag suspicious batch patterns for fraud detection

---

**END OF OFFLINE SYNC WORKFLOW**