# Scanning & Devices Domain

## 1. Scope & Responsibility

This domain owns:

- Scanning sessions for events (start/end)
- Device registration and authorization
- Ticket validation rules (valid, used, revoked, duplicate, wrong gate)
- Offline scanning flows & synchronization
- Real-time entry metrics

Out of scope:
- Ticket creation (Ticketing)
- Payment confirmation (Payments & Ledger)

---

## 2. Core Resources

### **Device**

Fields:
- `id`
- `organization_id`
- `name`, `device_identifier`
- `status` (active, disabled)
- `last_seen_at`

Invariants:
- Devices must be authorized to scan for a given event.

---

### **ScanningSession**

Fields:
- `id`
- `event_id`
- `organization_id`
- `started_by_user_id`
- `gate_id` (optional)
- `started_at`, `ended_at`

Invariants:
- One event may have multiple scanning sessions.

---

### **ScanEvent**

Represents a single scan attempt.

Fields:
- `id`
- `ticket_id`
- `event_id`
- `device_id`
- `result` (valid, duplicate, invalid, error)
- `scanned_at`
- `metadata`

Invariants:
- Stored for auditing.
- High volume → must be append-only.

---

## 3. Ticket Validation Rules

- Ticket belongs to event.
- Ticket not already scanned (or allow re-entry depending on event rules).
- Ticket status must be paid/active.
- Ticket must pass gate rules if applicable.

---

## 4. Performance Architecture

**Hot (ETS + Redis):**
- Ticket scan state:
  - Has the ticket been scanned already?
- Fast lookup by ticket code → event → ticket → scan status.

**Warm (Redis):**
- Ticket QR → TicketID lookup table.
- Scanning session metrics (counts per gate, per device).

**Cold (Postgres):**
- ScanEvent logs.
- Device history.

Redis structures:
- `scan:ticket:{ticket_id}` → Redis **string** (`"0"` or `"1"`)
- `scan:session:{session_id}` → Redis **counters**
- `scan:gate:{gate_id}` → Redis **counters**

---

## 5. Indexing & Query Patterns

Indexes:
- `(event_id, ticket_id)` on ScanEvent.
- `(device_id)` for debugging device issues.
- `(event_id, scanned_at)` for timelines.

Patterns:
- Validate ticket:
  - Decode QR → ticket_id → Redis scan key → fallback DB.
- Offline mode:
  - Validate against locally cached dataset → later sync via event queue.

---

## 6. PubSub & Real-time

Topics:
- `scanning:event:{event_id}`
- `scanning:session:{session_id}`

Broadcast:
- Real-time entry counters
- Duplicate scan warnings
- Device online/offline heartbeat

---

## 7. Error & Edge Cases

- Duplicate scans within seconds → must be blocked even under concurrency.
- QR tampering → must validate signature/structure.
- Device clock drift → rely on server timestamp.
- Offline scanning:
  - Must fail gracefully if local dataset outdated.

---

## 8. Domain Interactions

- **Ticketing** — determines ticket validity & entitlement.
- **Events** — time windows for scanning.
- **Analytics** — entry funnel metrics.
- **Reporting** — entry logs & throughput.

---

## 9. Testing & Observability

Tests:
- Duplicate detection.
- Invalid event scans.
- Gate-rule enforcement.

Telemetry:
- Entry throughput
- Duplicate scan attempts
- Device sync errors

---

## 10. Open Questions

- Do we allow re-entry?
- Gate-level capacity throttling?
- QR encryption vs signing?
