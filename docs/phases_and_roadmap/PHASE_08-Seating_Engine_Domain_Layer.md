## 💺 PHASE 8: Seating Engine Domain Layer

**Goal:** Seating resources, seat allocation/reservation workflows  
**Duration:** 2.5 weeks  
**Deliverables:** Layout, Section, Block, Seat resources; seated ticketing workflows  
**Dependencies:** Completes Phase 3

---

### Phase 8.1: Seating Layout & Section Resources

#### Sub-Phase 8.1.1: Create Layout Resource

**Task:** Define Layout resource representing venue seating configuration  
**Objective:** Enable reusable seating plans across events  
**Output:**  
- `lib/voelgoedevents/ash/resources/seating/layout.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_layouts.exs`  
**Note:**  
- Reference `/docs/domain/seating.md`
- Attributes: `id`, `organization_id`, `venue_id`, `name`, `description`, `total_capacity`, `status` (`:draft`, `:active`, `:archived`), `metadata`, timestamps

---

#### Sub-Phase 8.1.2: Create Section Resource

**Task:** Define Section resource (e.g., "Orchestra", "Balcony")  
**Objective:** Group seats into logical zones with pricing tiers  
**Output:**  
- `lib/voelgoedevents/ash/resources/seating/section.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_sections.exs`  
**Note:**  
- Reference `/docs/domain/seating.md`
- Attributes: `id`, `layout_id`, `organization_id`, `name`, `section_type` (`:seated`, `:standing`), `capacity`, `price_tier`, `metadata`, timestamps

---

### Phase 8.2: Block & Seat Resources

#### Sub-Phase 8.2.1: Create Block Resource

**Task:** Define Block resource (e.g., "Row A", "Block 101")  
**Objective:** Further subdivide sections into manageable units  
**Output:**  
- `lib/voelgoedevents/ash/resources/seating/block.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_blocks.exs`  
**Note:**  
- Reference `/docs/domain/seating.md`
- Attributes: `id`, `section_id`, `organization_id`, `name`, `capacity`, `metadata`, timestamps

---

#### Sub-Phase 8.2.2: Create Seat Resource

**Task:** Define Seat resource (individual seat with row/number)  
**Objective:** Enable per-seat inventory and allocation  
**Output:**  
- `lib/voelgoedevents/ash/resources/seating/seat.ex`
- Migration: `priv/repo/migrations/YYYYMMDDHHMMSS_create_seats.exs`  
**Note:**  
- Reference `/docs/domain/seating.md`
- Attributes: `id`, `block_id`, `organization_id`, `row`, `number`, `status` (`:available`, `:held`, `:sold`, `:blocked`), `metadata`, timestamps
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — cache seat status in Redis bitmaps

---

### Phase 8.3: Seated Ticketing Workflows

#### Sub-Phase 8.3.1: Extend Reserve Workflow for Seated Tickets

**Task:** Update reserve workflow to handle specific seat allocation  
**Objective:** Support per-seat holds with Redis bitmap tracking  
**Output:** Updated `lib/voelgoedevents/workflows/ticketing/reserve_seat.ex`  
**Note:**  
- Reference `/docs/workflows/reserve_seat.md` for full specification
- Apply **Standard VoelgoedEvents Caching Model** (see Appendix C) — use Redis SETBIT for seat occupancy
- Use DLM for critical section: `"hold:seat:#{seat_id}"`
- Validate seat is `:available` before hold

---

#### Sub-Phase 8.3.2: Extend Release Workflow for Seated Tickets

**Task:** Update release workflow to free specific seats  
**Objective:** Clear seat holds and restore availability  
**Output:** Updated `lib/voelgoedevents/workflows/ticketing/release_seat.ex`  
**Note:**  
- Reference `/docs/workflows/release_seat.md` for full specification
- Clear Redis bitmap bits for released seats
- Update Seat status: `:held` → `:available`

---