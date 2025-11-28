# GenServers & Workers

**AGENTS:**
This folder is for **Runtime State** (GenServers) that are NOT Oban jobs.
- **Examples:** `OccupancyServer` (Live counter), `SeatHoldServer` (Timer management).
- **Supervision:** Ensure these servers are started in `lib/voelgoedevents/application.ex` or a dedicated Supervisor.