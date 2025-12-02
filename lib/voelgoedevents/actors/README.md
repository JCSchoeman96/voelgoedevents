# Actors Layer (OTP GenServers/GenStage)

**Purpose (Hot State Tier):** Houses all dedicated OTP Actors (GenServers, GenStage, Task Supervisors) responsible for managing **hot, real-time state** and concurrency-critical logic.
**Boundary:** Logic that requires single-threaded state mutation (e.g., in-memory caches, high-velocity counter management, high-frequency PubSub event processing).
**Key Residents:** Modules like SeatHoldRegistry (GenServer), ConnectionManager, and real-time aggregators.
