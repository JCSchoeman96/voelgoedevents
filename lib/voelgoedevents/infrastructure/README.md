# Infrastructure Layer

## Purpose

This directory serves as the **abstraction layer for all external, non-Ash systems and services**. It acts as the boundary between the VoelgoedEvents domain logic and the external world.

The `infrastructure/` directory contains **generic Elixir clients and adapters** for:

- **Redis** - Caching, distributed locking, session storage
- **HTTP Clients** - External API integrations (payment gateways, etc.)
- **Distributed Lock Manager (DLM)** - Critical section coordination across nodes
- **Message Queues** - Background job systems (if not using Oban directly)
- **External Storage** - S3/blob storage clients
- **Monitoring & Observability** - APM integrations

---

## Critical Architectural Rule

### ⚠️ **NO ASH DOMAIN LOGIC ALLOWED**

Modules in this directory **MUST BE** pure infrastructure clients. They:

- ✅ **CAN** contain low-level protocol implementations
- ✅ **CAN** handle connection pooling, retries, circuit breaking
- ✅ **CAN** provide generic interfaces for external systems
- ✅ **CAN** contain configuration and connection management

- ❌ **CANNOT** contain business logic
- ❌ **CANNOT** reference Ash resources, domains, or actions
- ❌ **CANNOT** make business decisions (e.g., "Should this checkout succeed?")
- ❌ **CANNOT** contain domain-specific validation or calculations

### Why This Matters

**Separation of Concerns:** Business logic belongs in Ash resources and workflows. Infrastructure belongs here. This keeps:

- Business logic testable without external dependencies
- Infrastructure swappable (Redis → Memcached, Stripe → Yoco)
- Code maintainable and clear about responsibilities

### Example of CORRECT Usage

```elixir
# ✅ CORRECT: Generic distributed lock client
defmodule Voelgoedevents.Infrastructure.DistributedLock do
  @moduledoc """
  Generic distributed lock manager using Redis Redlock algorithm.

  This module knows NOTHING about seats, tickets, or events.
  It only knows how to acquire and release locks.
  """

  def acquire(resource_key, ttl_ms \\ 5000) do
    # Generic lock acquisition logic
  end

  def release(resource_key, lock_value) do
    # Generic lock release logic
  end
end
```

```elixir
# ✅ CORRECT: Business logic uses infrastructure
defmodule Voelgoedevents.Workflows.Seating.ReserveSeat do
  alias Voelgoedevents.Infrastructure.DistributedLock

  def reserve_seat(seat_id) do
    # This is business logic - knows about seats and reservations
    DistributedLock.with_lock("seat:#{seat_id}", fn ->
      # Domain logic: Check availability, mark as held, etc.
      Seat.mark_as_held(seat_id)
    end)
  end
end
```

### Example of INCORRECT Usage

```elixir
# ❌ INCORRECT: Infrastructure contains business logic
defmodule Voelgoedevents.Infrastructure.DistributedLock do
  def reserve_seat(seat_id) do
    # ❌ This module now knows about seats and business rules
    acquire("seat:#{seat_id}")

    # ❌ Business logic doesn't belong here
    if Seat.available?(seat_id) do
      Seat.mark_as_held(seat_id)
    end
  end
end
```

---

## Key Residents

### 1. Distributed Lock Manager (DLM)

**File:** `distributed_lock.ex`  
**Implemented In:** Phase 1.3.6  
**Purpose:** Provides distributed locking across multiple nodes using Redis Redlock algorithm

**Critical For:**

- Seat reservation finalization (prevents double-booking)
- Checkout completion (prevents race conditions)
- Inventory updates (atomic operations)

**API:**

```elixir
# Acquire lock with TTL
{:ok, lock_value} = DistributedLock.acquire("resource_id", 5000)

# Release lock
:ok = DistributedLock.release("resource_id", lock_value)

# Execute in lock context (recommended)
{:ok, result} = DistributedLock.with_lock("resource_id", fn ->
  # Critical section
end)
```

### 2. Redis Client

**File:** `redis_client.ex`  
**Purpose:** Wrapper around Redix for connection pooling and command execution

**Used For:**

- Cache storage (ETS → Redis → Postgres hierarchy)
- Session data
- Seat holds (Redis ZSET with TTL)
- Rate limiting counters
- Distributed locks

**API:**

```elixir
# Execute command
{:ok, value} = RedisClient.command(["GET", "key"])

# Pipeline multiple commands
{:ok, results} = RedisClient.pipeline([
  ["SET", "key1", "value1"],
  ["EXPIRE", "key1", 300]
])
```

### 3. HTTP Client (Future)

**File:** `http_client.ex` (to be implemented)  
**Purpose:** Generic HTTP client for external API calls

**Used For:**

- Payment gateway APIs (Paystack, Yoco)
- Webhook delivery
- External integrations

---

## File Organization

```
infrastructure/
├── README.md (this file)
├── distributed_lock.ex       # Redis-based DLM (Phase 1.3.6)
├── redis_client.ex            # Redis connection pool wrapper
├── http_client.ex             # Generic HTTP client (future)
├── storage_client.ex          # S3/blob storage (future)
└── monitoring/                # APM integrations (future)
    └── telemetry_adapter.ex
```

---

## Testing Strategy

Infrastructure modules should be tested **independently** of business logic:

```elixir
# Good test - tests infrastructure behavior
defmodule Voelgoedevents.Infrastructure.DistributedLockTest do
  test "acquire returns lock value" do
    assert {:ok, lock_value} = DistributedLock.acquire("test_resource")
    assert is_binary(lock_value)
  end

  test "concurrent acquires fail" do
    {:ok, _lock1} = DistributedLock.acquire("resource")
    assert {:error, :timeout} = DistributedLock.acquire("resource", 100, 1)
  end
end
```

Use **mocks** in domain tests to avoid external dependencies:

```elixir
# Good domain test - mocks infrastructure
defmodule Voelgoedevents.Workflows.Seating.ReserveSeatTest do
  import Mox

  test "reserve seat acquires lock" do
    expect(DistributedLockMock, :with_lock, fn _resource, fun -> fun.() end)

    assert :ok = ReserveSeat.reserve_seat(seat_id)
  end
end
```

---

## Migration Guide

### When Adding New Infrastructure

1. **Ask:** Is this a generic external system client?

   - ✅ Yes → Add to `infrastructure/`
   - ❌ No (contains business logic) → Add to `workflows/` or Ash resource

2. **Create module** with clear documentation of what it does and doesn't do

3. **Write tests** for infrastructure behavior only

4. **Use from workflows/resources** but never put domain logic in infrastructure

### When Refactoring Existing Code

If you find business logic in `infrastructure/`:

1. Extract business logic → Move to `workflows/` or Ash resource
2. Keep only infrastructure client → Leave in `infrastructure/`
3. Update tests to separate concerns

---

## Dependencies

Infrastructure modules may depend on:

- ✅ Elixir standard library
- ✅ External libraries (Redix, HTTPoison, ExAws, etc.)
- ✅ Configuration modules
- ✅ Logging/telemetry

Infrastructure modules **MUST NOT** depend on:

- ❌ Ash resources (`Voelgoedevents.Ash.Resources.*`)
- ❌ Ash domains (`Voelgoedevents.Ash.Domains.*`)
- ❌ Workflows (`Voelgoedevents.Workflows.*`)
- ❌ Business logic modules

---

## Questions?

If you're unsure whether something belongs in `infrastructure/`, ask:

1. **Could this module be used by a completely different application?**

   - ✅ Yes → Infrastructure
   - ❌ No → Domain logic

2. **Does this module know about VoelgoedEvents business concepts?**

   - ✅ Yes → Not infrastructure
   - ❌ No → Infrastructure

3. **Could we swap the underlying technology without changing business logic?**
   - ✅ Yes → Infrastructure
   - ❌ No → Mixed concerns (needs refactoring)

---

## References

- **Phase 1.3.6:** Distributed Lock Manager implementation
- **Roadmap:** `/docs/VOELGOEDEVENTS_FINAL_ROADMAP.md`
- **Architecture:** `/docs/architecture/01_foundation.md`

---

**Maintained By:** VoelgoedEvents Platform Team  
**Last Updated:** December 1, 2025  
**Status:** Active - Enforce strictly
