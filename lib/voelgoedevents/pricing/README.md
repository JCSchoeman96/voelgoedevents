# Pricing Calculation Service Layer

**Purpose (Phase 19):** Contains the highly optimized logic for dynamic price calculation.
**Boundary:** Calculates the final ticket price by combining base price, inventory tiers, and seating zone overrides.
**Performance:** Must be built for sub-50ms latency during high-volume checkout.
