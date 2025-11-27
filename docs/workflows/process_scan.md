# Workflow: Process Scan

**Scanner captures QR code → Platform validates ticket and records real-time check-in**

---

## 1. Purpose & Overview

**Process Scan** is the venue gate workflow that handles ticket verification at event entry points. It receives a scanned QR code from a mobile scanner device (iPad/Android tablet PWA), validates the ticket, prevents duplicate entry, records the scan in audit trail, updates real-time occupancy, and broadcasts status to scanner device and admin dashboard.

**Why it matters:**

- **Contactless entry:** QR/barcode scanning replaces manual entry (faster, safer, touchless)
- **Duplicate prevention:** 5-minute dedup window prevents same ticket entering twice (fraud detection)
- **Real-time occupancy:** Dashboard updates immediately as customers enter (capacity management)
- **Audit trail:** Every scan recorded with timestamp + device (security + compliance)
- **Offline resilience:** Scanner queues scans locally when offline, syncs on reconnect (hybrid mode)
- **Multi-gate support:** Each gate has dedicated scanner device with event context

---

## 2. High-Level Flow

```
Scanner Device (QR capture at venue gate)
  ↓
  [POST /api/scans {ticket_code, device_id}]
  ↓
Authenticate scanner device (bearer token)
  ↓
Validate ticket code format
  ↓
Check ETS hot cache (per-node, < 1ms)
  ├─ Hit + within 5 min: Deny (duplicate)
  └─ Miss or expired: Continue
  ↓
Check Redis warm cache (cluster-wide, < 10ms)
  ├─ Hit + within 5 min: Deny (duplicate)
  └─ Miss or expired: Continue
  ↓
Lookup Ticket in database
  ├─ Not found: Reject (invalid ticket)
  ├─ Status not :active/:scanned: Reject (used/voided)
  └─ Valid: Continue
  ↓
Verify event :live and gate open
  ↓
Create Scan record (atomic)
  ├─ Status: :admitted
  └─ Timestamp: server time
  ↓
Update Ticket status to :scanned
  ↓
Populate ETS + Redis caches (5-min TTL)
  ↓
Broadcast PubSub:
  ├─ gate:{gate_id} → Scanner device (show green ✓)
  └─ occupancy:{org_id}:{event_id} → Admin dashboard
  ↓
Write audit log
  ↓
Return HTTP 200 (admission confirmation)
```

---

## 3. Preconditions (Must Be True Before Starting)

### Scanner Device & Authentication
- ✅ Scanner device has valid authentication token (bearer token, not expired)
- ✅ Scanner device status is `:active` (not inactive/offline/deactivated)
- ✅ Scanner device is assigned to a gate (gate_id not null)
- ✅ Gate belongs to organization + event (org_id and event_id known)

### Ticket & Format Validation
- ✅ Ticket code has valid format (base62, 16 chars, e.g., "3KQR-7F92-4M1X")
- ✅ Ticket code can be parsed (not corrupted/malformed QR payload)

### Ticket Existence & State
- ✅ Ticket exists in database (previously purchased via complete_checkout)
- ✅ Ticket status is `:active` (not yet scanned) OR `:scanned` (re-entry allowed)
- ✅ Ticket is not in state `:used` (venue marked as entered) or `:voided` (refunded)
- ✅ Ticket belongs to organization (org_id match, multi-tenant isolation)
- ✅ Ticket belongs to event (event_id match, prevents cross-event entry)

### Event & Gate State
- ✅ Event status is `:live` (not draft, not ended, not archived)
- ✅ Gate is open (optional: status not `:closed`)
- ✅ Gate occupancy < hard capacity limit (if limit enforced)

### Anti-Fraud Prevention
- ✅ No duplicate scan of this ticket within last 5 minutes (ETS + Redis check)
- ✅ Scanner device timestamp within ±300 seconds of server time (clock skew tolerance)

### System State
- ✅ PostgreSQL database connection available
- ✅ Redis cache available (or graceful fallback mode enabled)
- ✅ Phoenix PubSub operational (for occupancy broadcasts)
- ✅ ETS table `:recent_scans` initialized on all nodes

---

## 4. Postconditions (What Is True After Success)

### Persistent State (PostgreSQL)

✅ **Scan Record Created**:
```
{
  id: UUID (newly generated),
  ticket_id: UUID,
  device_id: UUID,
  gate_id: UUID,
  event_id: UUID,
  organization_id: UUID,
  status: :admitted,
  scanned_at: DateTime.utc_now(),
  gate_name: "Main Entrance" (from gate),
  device_name: "iPad-Gate-1" (from scanner),
  reason_denied: nil,
  created_at: DateTime.utc_now(),
  updated_at: DateTime.utc_now()
}
```

✅ **Ticket Record Updated**:
```
status: :active → :scanned
scanned_at: DateTime.utc_now()
last_gate_id: {gate_id}
scan_count: incremented by 1
last_scanned_at: DateTime.utc_now()
```

### Cache Layers (Populated)

✅ **ETS (Per-Node Hot Cache)**:
```
Table: :recent_scans
Key: {org_id, ticket_code}
Value: %{
  ticket_id: UUID,
  scan_at: DateTime,
  gate_id: UUID,
  gate_name: string,
  status: :admitted
}
TTL: 300 seconds (5 minutes)
Lookup latency: < 1ms
```

✅ **Redis (Cluster-Wide Warm Cache)**:
```
STRING Key: voelgoed:org:{org_id}:ticket:{ticket_code}:last_scan
Value: "{scan_id}:{gate_id}:{unix_timestamp}"
TTL: 300 seconds

ZSET Key: voelgoed:org:{org_id}:event:{event_id}:scans:recent
Score: Unix timestamp
Member: "{ticket_id}:{device_id}:{gate_id}"
Use: Time-range queries for gate analytics
```

### Notifications & Audit

✅ **PubSub Broadcast (Gate Subscribers)**:
```
Topic: gate:{gate_id}
Message: {
  event: :ticket_admitted,
  ticket_code: "3KQR-7F92-4M1X",
  status: :admitted,
  seat_info: {
    seat_id: UUID,
    block_name: "Section A",
    row: "10",
    seat_number: "42"
  },
  scanned_at: ISO8601,
  gate_occupancy: N,
  timestamp: ISO8601
}
Recipients: Scanner device (iPad at gate), live gate dashboards
```

✅ **PubSub Broadcast (Admin Dashboard)**:
```
Topic: occupancy:{org_id}:{event_id}
Message: {
  event: :ticket_scanned,
  ticket_id: UUID,
  gate_id: UUID,
  gate_name: "Main Entrance",
  timestamp: ISO8601,
  gate_occupancy: current,
  total_occupancy: current,
  percent_full: percentage
}
Recipients: Admin dashboards, analytics workers, reporting systems
```

✅ **Audit Log Entry**:
```
{
  organization_id: org_id,
  user_id: nil (scanner device action, no user),
  action: :ticket_scanned,
  entity_type: :Scan,
  entity_id: scan_id,
  changes: {
    ticket_id: UUID,
    ticket_code: "3KQR-7F92-4M1X",
    gate_id: UUID,
    gate_name: string,
    device_id: UUID,
    device_name: string,
    status: :admitted
  },
  metadata: {
    device_id: UUID,
    ip_address: IP,
    user_agent: "Scanner-PWA/1.0"
  },
  timestamp: DateTime.utc_now()
}
```

### API Response (Admission Confirmation)

✅ **HTTP 200 OK** (First-Time Scan):
```json
{
  "status": "admitted",
  "ticket_code": "3KQR-7F92-4M1X",
  "ticket_id": "uuid-ticket-123",
  "seat_info": {
    "seat_id": "uuid-seat-456",
    "block_name": "Section A",
    "row": "10",
    "seat_number": "42"
  },
  "gate": {
    "gate_id": "uuid-gate-1",
    "gate_name": "Main Entrance"
  },
  "scanned_at": "2025-11-26T14:30:45Z",
  "occupancy": {
    "gate_current": 342,
    "gate_capacity": 500,
    "event_current": 1250,
    "event_capacity": 2000,
    "percent_full": 62
  },
  "message": "✓ Entry permitted. Welcome!"
}
```

✅ **HTTP 200 OK** (Duplicate Scan Within 5 Minutes):
```json
{
  "status": "denied",
  "reason": "already_scanned",
  "ticket_code": "3KQR-7F92-4M1X",
  "last_scanned_at": "2025-11-26T14:28:15Z",
  "seconds_since_last_scan": 150,
  "last_gate_name": "Main Entrance",
  "message": "✗ Ticket already scanned. Access denied."
}
```

### Failure Cases (Guaranteed NOT to happen on error)

❌ On **ANY error**, these are guaranteed NOT to happen:
- ✅ No duplicate Scan records created
- ✅ No false admissions (no security bypass)
- ✅ No Ticket state corruption
- ✅ No cache poisoning (incorrect dedup data)
- ✅ No audit log gaps (all attempts logged)
- ✅ No occupancy miscounts (cache invalidated on error)

---

## 5. Detailed Step-by-Step Workflow (Happy Path)

### Phase 1: Scanner Device Authentication

**Step 1: Scanner Device Submits Scan Request**

```
POST /api/scans
Content-Type: application/json
Authorization: Bearer {scanner_device_token}

{
  "ticket_code": "3KQR-7F92-4M1X",
  "device_id": "uuid-scanner-gate-1",
  "scanned_at": "2025-11-26T14:30:45Z",
  "offline_batch": false
}
```

**Step 2: Extract Scanner Device Credentials**

```
Process:
  1. Extract bearer token from Authorization header
     bearer_token = "Bearer abc123def456..."
     token = remove "Bearer " prefix
  
  2. Device ID from request body (verify matches token)
     device_id = "uuid-scanner-gate-1"
  
  3. Organization ID must be extracted from device (never from request)
     org_id = device.organization_id (embedded in token context)
```

**Step 3: Authenticate Scanner Device (Bearer Token)**

```
Process:
  1. Query ScanDevice table:
     {:ok, devices} = Ash.read(ScanDevice,
       filter: [
         device_token: bearer_token,
         status: :active
       ])
  
  2. Verify exactly one device matches:
     if length(devices) != 1 do
       {:error, :invalid_device_token}
     end
     
     device = List.first(devices)
  
  3. Cross-check device_id from request:
     if device.id != device_id do
       {:error, :device_mismatch}
     end
  
  4. Extract org_id + event_id from device context:
     org_id = device.organization_id
     
     # Get gate details
     {:ok, gate} = Ash.get(Gate, device.gate_id)
     event_id = gate.event_id
```

**Step 4: Verify Device Is Active and Assigned to Gate**

```
Process:
  1. Check device status:
     unless device.status == :active do
       {:error, :device_inactive, %{status: device.status}}
     end
  
  2. Verify gate assignment:
     unless device.gate_id do
       {:error, :device_not_assigned_to_gate}
     end
  
  3. Fetch gate details:
     {:ok, gate} = Ash.get(Gate, device.gate_id)
     
     org_id = gate.organization_id
     event_id = gate.event_id
     gate_name = gate.name
     gate_capacity = gate.capacity
```

### Phase 2: Timestamp & Format Validation

**Step 5: Parse and Validate Scanner Timestamp**

```
Process:
  1. Parse ISO8601 timestamp from request:
     {:ok, scanned_at_device} = DateTime.from_iso8601(params["scanned_at"])
  
  2. Get current server time:
     now = DateTime.utc_now()
  
  3. Calculate time difference:
     time_diff_seconds = DateTime.diff(now, scanned_at_device, :second)
  
  4. Validate clock skew (tolerance: ±300 seconds = 5 minutes):
     if abs(time_diff_seconds) > 300 do
       {:error, :timestamp_out_of_range, %{
         server_time: now,
         device_time: scanned_at_device,
         diff_seconds: time_diff_seconds
       }}
     end
  
  5. Use server time as source of truth (ignore device time):
     final_scanned_at = DateTime.utc_now()
```

**Step 6: Validate Ticket Code Format**

```
Process:
  1. Extract ticket code:
     ticket_code = params["ticket_code"]  # e.g., "3KQR-7F92-4M1X"
  
  2. Validate format:
     # Length must be exactly 16 characters
     unless String.length(ticket_code) == 16 do
       {:error, :invalid_ticket_code_length, %{provided: String.length(ticket_code)}}
     end
     
     # Pattern: base62 with dashes (XXXX-XXXX-XXXX)
     pattern = ~r/^[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$/
     unless String.match?(ticket_code, pattern) do
       {:error, :invalid_ticket_code_format}
     end
```

### Phase 3: Duplicate Detection (Three-Tier Caching)

**Step 7: Check ETS Hot Cache (Per-Node, < 1ms)**

```
Process:
  1. Construct ETS key (includes org_id for multi-tenancy):
     ets_key = {org_id, ticket_code}
  
  2. Lookup in ETS table:
     case :ets.lookup(:recent_scans, ets_key) do
       [{_, cached_scan}] ->
         # Found in cache
         
         time_since_scan = DateTime.diff(final_scanned_at, cached_scan.scan_at, :second)
         
         if time_since_scan < 300 do  # 5 minutes
           # Duplicate scan detected
           {:error, :duplicate_scan, %{
             last_scan_at: cached_scan.scan_at,
             seconds_since: time_since_scan,
             last_gate: cached_scan.gate_name,
             cache_layer: :ets
           }}
         else
           # Cache expired, proceed to DB
           continue_to_step_9(ticket_code)
         end
       
       [] ->
         # Not in ETS, check Redis
         continue_to_step_8(ticket_code)
     end
```

**Step 8: Check Redis Warm Cache (Cluster-Wide, < 10ms)**

```
Process:
  1. Construct Redis key (includes org_id for multi-tenancy):
     redis_key = "voelgoed:org:#{org_id}:ticket:#{ticket_code}:last_scan"
  
  2. Query Redis:
     case Redix.command!(:redis, ["GET", redis_key]) do
       nil ->
         # Not in Redis, check database
         continue_to_step_9(ticket_code)
       
       cached_data ->
         # Parse cached value: "{scan_id}:{gate_id}:{unix_timestamp}"
         [_, _, cached_unix_ts_str] = String.split(cached_data, ":")
         
         cached_unix_ts = String.to_integer(cached_unix_ts_str)
         cached_scan_time = DateTime.from_unix!(cached_unix_ts)
         
         time_since = DateTime.diff(final_scanned_at, cached_scan_time, :second)
         
         if time_since < 300 do  # 5 minutes
           # Duplicate detected on another node (cluster-wide)
           {:error, :duplicate_scan_distributed, %{
             last_scan_at: cached_scan_time,
             seconds_since: time_since,
             cache_layer: :redis
           }}
         else
           # Cache expired, proceed to DB
           continue_to_step_9(ticket_code)
         end
     end
```

### Phase 4: Database Lookup & Validation

**Step 9: Fetch Ticket from Database**

```
Process:
  1. Query Ticket table (multi-tenant scoped):
     {:ok, tickets} = Ash.read(Ticket,
       filter: [
         ticket_code: ticket_code,
         organization_id: org_id,
         event_id: event_id
       ])
  
  2. Handle results:
     case tickets do
       [ticket] ->
         # Found exactly one ticket
         continue_to_step_10(ticket)
       
       [] ->
         {:error, :ticket_not_found, %{ticket_code: ticket_code}}
       
       _multiple ->
         {:error, :duplicate_ticket_code_in_db}
     end

Purpose:
  - Ensure ticket exists (not forged/invalid code)
  - Verify tenant isolation (org_id filter)
  - Verify event match (prevents cross-event entry)
```

**Step 10: Verify Ticket Status**

```
Process:
  1. Check ticket status:
     case ticket.status do
       :active ->
         # New scan, allowed
         continue_to_step_12(ticket)
       
       :scanned ->
         # Re-entry allowed (allow venue re-entry)
         # Check if within 5-minute window
         time_since_last = DateTime.diff(final_scanned_at, ticket.scanned_at, :second)
         
         if time_since_last < 300 do
           # Too soon, deny (duplicate)
           {:error, :already_scanned_recently, %{
             last_scanned_at: ticket.scanned_at,
             seconds_since: time_since_last
           }}
         else
           # > 5 min ago, allow re-entry
           continue_to_step_12(ticket)
         end
       
       :used ->
         {:error, :ticket_already_used}
       
       :voided ->
         {:error, :ticket_voided}
       
       :refunded ->
         {:error, :ticket_refunded}
     end
```

**Step 11: Verify Event Is Live**

```
Process:
  1. Fetch event details:
     {:ok, event} = Ash.get(Event, event_id)
  
  2. Check status:
     unless event.status == :live do
       {:error, :event_not_live, %{
         current_status: event.status,
         expected: :live
       }}
     end
  
  3. Optional: Check event hasn't ended:
     if event.end_time && DateTime.compare(now, event.end_time) == :gt do
       {:error, :event_ended}
     end
```

**Step 12: Verify Gate Capacity (Optional Hard Limit)**

```
Process:
  1. Check if gate has hard capacity limit:
     if gate.hard_capacity_limit do
       # Calculate current gate occupancy
       current_occupancy = calculate_gate_occupancy(gate.id)
       
       if current_occupancy >= gate.hard_capacity_limit do
         {:error, :gate_at_capacity, %{
           capacity: gate.hard_capacity_limit,
           current: current_occupancy
         }}
       end
     end

Purpose:
  - Venue control: Prevent overcrowding at specific gate
  - Optional: May allow overselling at different gates
  - Soft limit: Return warning but allow (admin decision)
```

### Phase 5: Scan Recording (Atomic Transaction)

**Step 13: Create Scan Record (Atomic)**

```
Process:
  1. Begin transaction (all-or-nothing):
     {:ok, {scan, updated_ticket}} = Ash.Repo.transaction(fn ->
  
  2. Create Scan record:
     {:ok, scan} = Ash.create(Scan, %{
       "ticket_id" => ticket.id,
       "device_id" => device.id,
       "gate_id" => gate.id,
       "event_id" => event_id,
       "organization_id" => org_id,
       "status" => :admitted,
       "scanned_at" => final_scanned_at,
       "gate_name" => gate.name,
       "device_name" => device.name,
       "reason_denied" => nil
     }, authorize?: false)
  
  3. Update Ticket status:
     {:ok, updated_ticket} = Ash.update(ticket, :scan, %{
       "scanned_at" => final_scanned_at,
       "last_gate_id" => gate.id,
       "scan_count" => (ticket.scan_count || 0) + 1
     }, authorize?: false)
  
  4. Return both records:
     {:ok, {scan, updated_ticket}}
     end)
  
  5. Handle transaction result:
     case result do
       {:ok, {scan, ticket}} ->
         continue_to_phase_6(scan, ticket)
       
       {:error, reason} ->
         {:error, :transaction_failed, reason}
     end
```

### Phase 6: Cache Population (Dedup Window)

**Step 14: Populate ETS Hot Cache**

```
Process:
  1. Store in per-node ETS table:
     ets_key = {org_id, ticket_code}
     ets_value = %{
       ticket_id: ticket.id,
       scan_at: final_scanned_at,
       gate_id: gate.id,
       gate_name: gate.name,
       status: :admitted,
       device_id: device.id
     }
     
     :ets.insert(:recent_scans, {ets_key, ets_value})
  
  2. TTL management (5 minutes):
     # Option A: Manual cleanup (background job)
     # Every 6 minutes, scan table for expired entries
     
     # Option B: Per-entry TTL (requires ETS with TTL support)
     # TTL automatically expires after 300 seconds
```

**Step 15: Populate Redis Warm Cache (Cluster-Wide)**

```
Process:
  1. Store ZSET for time-range analytics:
     zset_key = "voelgoed:org:#{org_id}:event:#{event_id}:scans:recent"
     zset_member = "#{ticket.id}:#{device.id}:#{gate.id}"
     zset_score = DateTime.to_unix(final_scanned_at)
     
     Redix.command!(:redis, [
       "ZADD",
       zset_key,
       zset_score,
       zset_member
     ])
  
  2. Store STRING for fast dedup lookup:
     string_key = "voelgoed:org:#{org_id}:ticket:#{ticket_code}:last_scan"
     string_value = "#{scan.id}:#{gate.id}:#{zset_score}"
     
     Redix.command!(:redis, [
       "SET",
       string_key,
       string_value,
       "EX",
       "300"  # TTL: 300 seconds (5 minutes)
     ])
  
  3. Cleanup ZSET (remove old entries > 5 min old):
     cutoff_time = DateTime.to_unix(DateTime.utc_now()) - 300
     
     Redix.command!(:redis, [
       "ZREMRANGEBYSCORE",
       zset_key,
       "-inf",
       cutoff_time
     ])

Purpose:
  - Fast dedup lookup on all nodes (cluster-wide)
  - ZSET enables gate analytics queries (time ranges)
  - TTL prevents stale entries accumulating
```

### Phase 7: Real-Time Notifications

**Step 16: Broadcast to Gate Subscribers (Scanner Device)**

```
Process:
  1. Construct gate topic:
     topic = "gate:#{gate.id}"
  
  2. Prepare message:
     message = %{
       event: :ticket_admitted,
       ticket_code: ticket_code,
       status: :admitted,
       seat_info: %{
         seat_id: ticket.seat_id,
         block_name: get_seat_block_name(ticket.seat_id),
         row: get_seat_row(ticket.seat_id),
         seat_number: get_seat_number(ticket.seat_id)
       },
       scan_time: DateTime.to_iso8601(final_scanned_at),
       gate_occupancy: calculate_gate_occupancy(gate.id)
     }
  
  3. Broadcast via Phoenix PubSub:
     Phoenix.PubSub.broadcast(Voelgoedevents.PubSub, topic, message)
  
  4. Subscribers:
     - Scanner device (iPad at gate): Show green checkmark + beep
     - Gate live dashboard: Update seat count + occupancy bar
```

**Step 17: Broadcast to Admin Dashboard (Occupancy Update)**

```
Process:
  1. Construct occupancy topic:
     topic = "occupancy:#{org_id}:#{event_id}"
  
  2. Calculate updated occupancy:
     gate_occupancy = calculate_gate_occupancy(gate.id)
     total_occupancy = calculate_total_occupancy(event_id)
     percent_full = (total_occupancy / event.capacity) * 100
  
  3. Prepare message:
     message = %{
       event: :ticket_scanned,
       ticket_id: ticket.id,
       gate_id: gate.id,
       gate_name: gate.name,
       timestamp: DateTime.to_iso8601(final_scanned_at),
       gate_occupancy: gate_occupancy,
       total_occupancy: total_occupancy,
       percent_full: percent_full,
       occupancy_levels: %{
         gates: [
           %{gate_id: g1, occupancy: n1, capacity: c1, percent: p1},
           %{gate_id: g2, occupancy: n2, capacity: c2, percent: p2}
         ]
       }
     }
  
  4. Broadcast via Phoenix PubSub:
     Phoenix.PubSub.broadcast(Voelgoedevents.PubSub, topic, message)
  
  5. Subscribers:
     - Admin dashboard (LiveView): Update occupancy gauge + gate counts
     - Analytics workers: Track entry patterns + velocity
     - Real-time reporting: Populate event metrics
```

### Phase 8: Audit & Response

**Step 18: Write Audit Log Entry**

```
Entry:
  {
    organization_id: org_id,
    user_id: nil,  # Scanner device action, not user-initiated
    action: :ticket_scanned,
    entity_type: :Scan,
    entity_id: scan.id,
    
    changes: %{
      ticket_id: ticket.id,
      ticket_code: ticket_code,
      gate_id: gate.id,
      gate_name: gate.name,
      device_id: device.id,
      device_name: device.name,
      status: :admitted,
      scan_count: ticket.scan_count
    },
    
    metadata: %{
      device_id: device.id,
      device_name: device.name,
      ip_address: get_client_ip(conn),
      user_agent: "Scanner-PWA/1.0"
    },
    
    timestamp: DateTime.utc_now()
  }
  |> Ash.create!(AuditLog)

Purpose:
  - Compliance: Non-repudiation (proof of entry)
  - Support: Troubleshooting (when/where entry happened)
  - Fraud: Historical record for security investigation
  - Analytics: Entry patterns by gate/time/device
```

**Step 19: Return HTTP 200 OK (Admission Confirmation)**

```
Response:
  HTTP/1.1 200 OK
  Content-Type: application/json
  
  {
    "status": "admitted",
    "ticket_code": "3KQR-7F92-4M1X",
    "ticket_id": "uuid-ticket-123",
    "seat_info": {
      "seat_id": "uuid-seat-456",
      "block_name": "Section A",
      "row": "10",
      "seat_number": "42"
    },
    "gate": {
      "gate_id": "uuid-gate-1",
      "gate_name": "Main Entrance"
    },
    "scanned_at": "2025-11-26T14:30:45Z",
    "occupancy": {
      "gate_current": 342,
      "gate_capacity": 500,
      "event_current": 1250,
      "event_capacity": 2000,
      "percent_full": 62
    },
    "message": "✓ Entry permitted. Welcome!"
  }

HTTP Status Semantics:
  - 200 OK: "Scan processed" (admission or denial, both return 200)
  - 4xx: "Bad request" (invalid device, malformed payload)
  - 5xx: "Server error" (DB down, system error)
```

**Step 20: Scanner Device Updates UI (PWA)**

```javascript
// Svelte component on scanner tablet

onMessage(message) {
  if (message.status === "admitted") {
    // Show green checkmark
    showGreen();
    
    // Play success sound
    playBeep({frequency: 1000, duration: 200});
    
    // Display seat info (for staff verification)
    displaySeat(message.seat_info);
    updateOccupancy(message.occupancy);
    
    // Haptic feedback (vibration)
    navigator.vibrate(100);
    
    // Auto-clear after 2 seconds, ready for next scan
    setTimeout(() => {
      clearDisplay();
      focusQRReader();  // Re-open camera
    }, 2000);
  } else if (message.status === "denied") {
    // Show red X
    showRed();
    
    // Play error sound
    playError({frequency: 400, duration: 500});
    
    // Display denial reason
    displayReason(message.reason);
    
    // Haptic feedback (double vibration)
    navigator.vibrate([100, 50, 100]);
    
    // Hold for 3 seconds (let staff read message)
    setTimeout(() => {
      clearDisplay();
      focusQRReader();
    }, 3000);
  }
}
```

---

## 6. Edge Cases & Failure Modes

| Edge Case | Cause | Prevention | Recovery |
|-----------|-------|-----------|----------|
| **Duplicate scan (< 5 min)** | Same ticket scanned twice | ETS + Redis 5-min dedup window | Return :already_scanned, deny entry |
| **Gate re-entry (> 5 min)** | Same ticket scanned after 5 min | Allow if time > 300 sec | Permit scan, update ticket |
| **Device offline** | Scanner loses internet connection | Fallback to offline queue (IndexedDB) | Queue scan locally, sync on reconnect (see offline_sync.md) |
| **Clock skew > 5 min** | Scanner device clock drift | Timestamp validation (±300 sec tolerance) | Reject, alert to check device time |
| **Ticket not found** | Invalid/forged ticket code | Query database with org_id filter | Return 404, alert security |
| **Ticket already used** | Venue staff marked as :used | Check status != :used | Deny entry, show "Already used" |
| **Event not live** | Event ended or in draft state | Verify event.status == :live | Deny entry, show "Event inactive" |
| **Device inactive** | Scanner device deactivated/offline | Check device.status == :active | Return 401, require device re-auth |
| **Gate at capacity** | Hard limit reached | Check gate.current >= capacity | Deny entry, show "Gate full" |
| **Database connection lost** | PostgreSQL unavailable | Fallback to cache + offline queue | Cache hit: admit, queue for sync |
| **Redis down** | Cache cluster unavailable | Proceed with DB + ETS checks | Fallback: ETS dedup only, slower |
| **ETS lookup fails** | Table not initialized | Verify :recent_scans table exists | Proceed to Redis, slower dedup |
| **Ticket belongs to another org** | Cross-tenant access attempt | Query includes org_id filter | Reject, log security alert |
| **Ticket for different event** | Wrong event ticket at gate | Query includes event_id filter | Reject, show "Wrong event" |
| **PubSub broadcast fails** | Message broker down | Async fire-and-forget (don't block) | Log warning, occupancy updates via polling |

---

## 7. Offline Scanning (Hybrid Mode)

### Offline Queue (IndexedDB on Scanner Device)

```javascript
// Scanner PWA stores scans locally when offline

async function scanQROffline(ticketCode) {
  try {
    // Attempt online scan first
    const response = await fetch('/api/scans', {
      method: 'POST',
      headers: {'Authorization': `Bearer ${deviceToken}`},
      body: JSON.stringify({
        ticket_code: ticketCode,
        device_id: getDeviceId(),
        scanned_at: new Date().toISOString(),
        offline_batch: false
      })
    });
    
    if (response.ok) {
      const result = await response.json();
      showGreen();  // Online scan succeeded
      return;
    }
  } catch (e) {
    // Network error or timeout → store in IndexedDB (offline queue)
    const scan = {
      ticket_code: ticketCode,
      scanned_at: new Date().toISOString(),
      device_id: getDeviceId(),
      gate_id: getGateId(),
      status: 'pending',
      created_at: Date.now()
    };
    
    // Store in local IndexedDB
    const db = await openDatabase();
    await db.scans.add(scan);
    
    showYellow();  // "Stored locally"
    playWarning();
  }
}

// On reconnect (connection re-established):
// WorkerSyncOfflineScans job runs (see offline_sync.md)
// Syncs pending scans to server in batch
```

**Reference:** See `docs/workflows/offline_sync.md` for full offline sync workflow.

---

## 8. Multi-Tenancy & Security

### Organization Isolation (CRITICAL)

**Rule 1: Extract org_id from Authenticated Device**

```elixir
# ✅ CORRECT (org_id embedded in device token context)
case Ash.read(ScanDevice, filter: [device_token: bearer_token]) do
  {:ok, [device]} ->
    org_id = device.organization_id  # From device record
    # All queries filtered by this org
end

# ❌ WRONG (org_id from request params)
org_id = params["organization_id"]  # User can spoof!
```

**Rule 2: All Database Queries Include org_id Filter**

```elixir
# ✅ CORRECT
Ash.read(Ticket, filter: [
  organization_id: org_id,
  event_id: event_id,
  ticket_code: ticket_code
])

# ❌ WRONG
Ash.read(Ticket, filter: [ticket_code: ticket_code])  # Missing org_id!
```

**Rule 3: Redis Keys Always Include org_id**

```
✅ voelgoed:org:{org_id}:ticket:{ticket_code}:last_scan
✅ voelgoed:org:{org_id}:event:{event_id}:scans:recent

❌ voelgoed:ticket:{ticket_code}:last_scan      (no org!)
❌ voelgoed:scans:recent                         (cross-org collision!)
```

**Rule 4: ETS Keys Include org_id**

```elixir
# ✅ CORRECT
ets_key = {org_id, ticket_code}

# ❌ WRONG
ets_key = ticket_code                             # Cross-org collision!
```

### Scanner Device Authentication

```elixir
# Bearer token strategy: OAuth-style with refresh capability

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
# - Stored as hash in database (never plain text)
# - Rotatable per device (admin function)
# - Scoped to specific device (can't use on other scanners)
# - TTL can be enforced (optional: token expires after N days)
```

### Fraud Detection & Alerts

```elixir
# Flag suspicious scan patterns:

1. Impossible travel (same ticket at 2 gates < 5 min apart):
   if time_between_gates < 300 and gates_far_apart do
     alert_security(:impossible_travel, ticket_id)
   end

2. Repeated duplicate attempts:
   if duplicate_attempt_count > 5 in_last_hour do
     alert_security(:repeated_duplicates, ticket_id)
   end

3. High velocity scans at gate (> 60 per minute):
   if scan_velocity > 60 do
     alert_security(:high_velocity, gate_id)
   end

4. Device suspicious activity (too many errors):
   if device_error_rate > 0.1 do
     alert_security(:device_malfunction, device_id)
   end

# Actions: Log, alert staff, flag for manual review, optionally block device
```

### Sensitive Data Handling

- **Don't expose:** Customer names, payment info, full email addresses
- **Do expose:** Ticket code, seat location (block/row/seat), gate name, timestamp
- **Log:** All scans in audit trail (comply with venue security requirements)
- **Secure:** QR codes are tickets — treat as sensitive until scanned

---

## 9. Performance & Consistency

### Three-Tier Caching Strategy

**Hot Layer: ETS (Per-Node)**
```
Table: :recent_scans
Key: {org_id, ticket_code}
Value: %{ticket_id, scan_at, gate_id, status}
TTL: 300 seconds (auto-evict)
Latency: < 1ms (in-memory)
Concurrency: Ets is thread-safe for reads/writes
```

**Warm Layer: Redis (Cluster-Wide)**
```
STRING Key: voelgoed:org:{org_id}:ticket:{ticket_code}:last_scan
Value: "{scan_id}:{gate_id}:{unix_timestamp}"
TTL: 300 seconds (auto-expire)
Latency: < 10ms (network + replication)

ZSET Key: voelgoed:org:{org_id}:event:{event_id}:scans:recent
Score: Unix timestamp
Member: "{ticket_id}:{device_id}:{gate_id}"
Use: Time-range analytics (gate patterns)
```

**Cold Layer: PostgreSQL**
```
Table: scans
Indexes:
  - (ticket_id, scanned_at DESC) — "Recent scans for ticket"
  - (gate_id, scanned_at DESC) — "Gate occupancy snapshot"
  - (event_id, scanned_at DESC) — "Event analytics"

Latency: 5-50ms
Use case: Durability, audit trail, historical analytics
```

### Performance Targets

| Operation | Latency | Notes |
|-----------|---------|-------|
| Scanner auth (device token lookup) | < 5ms | Indexed query |
| Ticket code validation | < 1ms | Regex match in memory |
| ETS dedup check (hit) | < 1ms | Hash lookup |
| Redis dedup check (hit) | < 10ms | Network round-trip |
| Ticket lookup (DB) | 5-20ms | Indexed by ticket_code + org_id |
| Scan creation (atomic) | 10-50ms | Write + index update |
| Cache population (ETS + Redis) | 5-15ms | Parallel inserts |
| PubSub broadcast | 1-5ms | Fire-and-forget |
| **Total admission response** | **50-150ms** | Typical end-to-end |

---

## 10. Implementation Targets

### Ash Resources & Actions

**1. Scan Resource (:create action)**

```
Module: Voelgoedevents.Ash.Resources.Scanning.Scan
File: lib/voelgoedevents/ash/resources/scanning/scan.ex

Actions:
  :create
    - Arguments: ticket_id, device_id, gate_id, event_id, status
    - Changes: Set attributes as provided
    - Validations:
      - :ticket_exists (verify ticket_id references valid ticket)
      - :device_exists (verify device_id references valid scanner)
      - :gate_exists (verify gate_id references valid gate)
      - :status_admitted (ensure status in [:admitted, :denied])
      - :organization_matches (multi-tenancy: verify all belong to same org)
```

**2. Ticket Resource (:scan action)**

```
Module: Voelgoedevents.Ash.Resources.Ticketing.Ticket
File: lib/voelgoedevents/ash/resources/ticketing/ticket.ex

Actions:
  :scan
    - Arguments: (none, called after Scan created)
    - Changes:
      - Set status → :scanned
      - Set scanned_at → DateTime.utc_now()
      - Set last_gate_id → gate_id
      - Increment scan_count
    - Validations:
      - :status_active_or_scanned (only :active or :scanned tickets)
```

**3. ScanDevice Resource (Already Defined)**

```
Module: Voelgoedevents.Ash.Resources.Scanning.ScanDevice
File: lib/voelgoedevents/ash/resources/scanning/scan_device.ex

Attributes:
  - device_token: String (hashed, unique)
  - device_name: String (display name, e.g., "iPad-Gate-1")
  - gate_id: UUID (foreign key to Gate)
  - organization_id: UUID (multi-tenancy)
  - status: Atom (:active, :inactive, :offline)
  - last_heartbeat: DateTime (track device connectivity)
```

### Phoenix Controllers & Endpoints

**Scan Endpoint**

```
POST /api/scans
  - Authenticated: Bearer token (ScanDevice)
  - Parameters: {ticket_code, device_id, scanned_at}
  - Response: 200 OK {status, ticket_id, seat_info, occupancy}
  - Error codes: 
    - 401 Unauthorized (invalid device token)
    - 404 Not Found (ticket not found)
    - 409 Conflict (duplicate scan)
    - 422 Unprocessable (validation error)
    - 500 Server Error (database error)
```

---

## 11. Monitoring & Observability

### Key Metrics

```
1. Scan success rate (per minute)
   - Target: > 99%
   - Alert if < 95% (device issues or system problems)

2. Average scan latency (p50, p95, p99)
   - Target: < 100ms (p95)
   - Alert if > 500ms (database or cache issues)

3. Duplicate scan detection rate
   - Monitor: % of scans caught as duplicates (should be low, ~0.1%)
   - Alert if > 5% (indicates fraud or device malfunction)

4. Gate occupancy (real-time tracking)
   - Monitor: Current count vs capacity per gate
   - Alert if gate approaching capacity (90%+)

5. Scanner device connectivity
   - Monitor: Last heartbeat timestamp per device
   - Alert if > 5 min since last heartbeat (device offline)

6. Cache hit rates
   - ETS dedup hit rate (should be high for busy gates)
   - Redis dedup hit rate
   - Low hit rate = increase TTL or check cache eviction
```

### Alerts

```
- High scan failure rate → Check database + Redis health
- High scan latency → Database performance issue? Cache down?
- Low dedup hit rate → Is 5-minute TTL appropriate for event traffic?
- Gate at capacity → Alert venue staff to open additional gates
- Device offline → Alert IT, may need restart or network troubleshooting
```

---

## 12. Integration Points

### With `complete_checkout.md`
```
Workflow sequence:
  1. complete_checkout: Creates Ticket records (status: :active)
  2. process_scan: Scans ticket (status: :active → :scanned)
  
Connection: Ticket must exist before scanning (issued by complete_checkout)
```

### With `offline_sync.md`
```
Hybrid scanning:
  1. process_scan: Online scanning (live updates)
  2. offline_sync: Offline queue → later synced to server
  
Connection: Offline scans stored in IndexedDB, batch-synced later
Reference: See docs/workflows/offline_sync.md for full details
```

### With `scanning_devices.md`
```
Device management:
  1. scanning_devices: Admin configures scanners, assigns to gates
  2. process_scan: Uses device context (gate, org, event)
  
Connection: ScanDevice token authenticates scanner PWA
Reference: See docs/domain/scanning_devices.md for device lifecycle
```

---

## 13. Future Enhancements

- **Age verification:** Scan ticket + verify customer age (age-restricted events)
- **Multi-entry venues:** Allow same ticket to re-enter throughout day (day-pass)
- **Priority queues:** Separate lanes for VIP vs general admission (expedited entry)
- **RFID wristbands:** Wristband + QR fallback (festivals, higher throughput)
- **Facial recognition:** Optional biometric verification at gates (high-security events)
- **Analytics dashboard:** Real-time bottleneck detection (which gate is slow)
- **Waitlist auto-admission:** Automatically admit from waitlist when capacity drops

---

**END OF PROCESS SCAN WORKFLOW**