## 📱 PHASE 5: Scanning Backend & Integration

**Goal:** Scanning API endpoints, device authentication, online validation  
**Duration:** 2 weeks  
**Deliverables:** Scan, ScanSession, Device resources; process_scan workflow  
**Dependencies:** Completes Phase 4

---

### Phase 5.1: Device & ScanSession Resources

#### Sub-Phase 5.1.1: Create Device Resource

**Task:** Define Device resource for scanner device authentication and tracking  
**Objective:** Enable secure device registration and session management  
**Output:**  
- `lib/voelgoedevents/ash/resources/scanning/device.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_devices.exs`  
**Note:**  
- Each device has unique `device_id` and API token
- Attributes: `id`, `organization_id`, `device_id` (unique), `name`, `device_type` (`:scanner`, `:mobile`), `status` (`:active`, `:inactive`), `last_seen_at`, `settings`, timestamps
- Policies: Organization admins can register/revoke devices

---

#### Sub-Phase 5.1.2: Create ScanSession Resource

**Task:** Define ScanSession resource linking device to event/gate for shift tracking  
**Objective:** Track which devices are scanning at which gates  
**Output:**  
- `lib/voelgoedevents/ash/resources/scanning/scan_session.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_scan_sessions.exs`  
**Note:**  
- Attributes: `id`, `organization_id`, `device_id`, `event_id`, `gate_id`, `status` (`:active`, `:ended`), `started_at`, `ended_at`, `scan_count`
- One active session per device at a time

---

### Phase 5.2: Scan Resource

#### Sub-Phase 5.2.1: Create Scan Resource

**Task:** Define Scan resource to record each scan attempt  
**Objective:** Enable audit trail and deduplication  
**Output:**  
- `lib/voelgoedevents/ash/resources/scanning/scan.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_scans.exs`  
**Note:**  
- Attributes: `id`, `organization_id`, `ticket_id`, `event_id`, `device_id`, `gate_id`, `scan_session_id`, `result` (`:valid`, `:duplicate`, `:invalid_token`, `:wrong_event`, `:wrong_gate`), `scanned_at`, `metadata`
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — cache recent scans in ETS for 5-min dedup window

---

### Phase 5.3: Process Scan Workflow

#### Sub-Phase 5.3.1: Implement Process Scan Workflow (Online)

**Task:** Create workflow for online scan validation  
**Objective:** Validate ticket QR codes with deduplication and status updates  
**Output:** `lib/voelgoedevents/workflows/scanning/process_scan.ex`  
**Note:**  
- Reference `/docs/workflows/process_scan.md` for full specification (do NOT duplicate steps)
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C):
  - Three-tier dedup: ETS (1ms) → Redis (10ms) → DB (50ms)
- Workflow steps (high-level):
  1. Authenticate scanner device (bearer token)
  2. Parse ticket code (16-char base62)
  3. Check ETS cache for recent scan (5-min window)
  4. Verify QR signature (Phoenix.Token)
  5. Fetch ticket from DB (validate status, event, gate)
  6. Update ticket status (`:active` → `:scanned`)
  7. Create Scan record
  8. Populate ETS + Redis caches
  9. Broadcast PubSub occupancy update
  10. Return result (`:valid`, `:duplicate`, `:invalid_token`, etc.)

---

### Phase 5.4: Scanning API Endpoints

#### Sub-Phase 5.4.1: Create Scanning API Controller

**Task:** Implement JSON API endpoints for scanner devices  
**Objective:** Enable RESTful communication between scanner apps and backend  
**Output:** `lib/voelgoedevents_web/controllers/scanning/scan_controller.ex`  
**Note:**  
- Endpoints:
  - `POST /api/v1/scanning/sessions` — Start scan session
  - `POST /api/v1/scanning/scan` — Process single scan
  - `GET /api/v1/scanning/sessions/:id` — Get session details
  - `PUT /api/v1/scanning/sessions/:id/end` — End session
- Authenticate using device bearer tokens
- Reference `/docs/coding_style/phoenix_liveview.md` for controller conventions

---