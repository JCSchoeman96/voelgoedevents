defmodule Voelgoedevents.Infrastructure.DistributedLock do
  @moduledoc """
  Redis-based distributed lock implementation using Redlock-style atomic operations.

  Provides cross-node, exclusive lock primitive that prevents simultaneous writes to
  shared state (like seat inventory or order creation).

  ## Architecture

  - **Lock Acquisition**: Uses Redis `SET key value NX PX ttl_ms` for atomic lock creation
  - **Lock Release**: Uses Lua script to ensure only the lock owner can release it
  - **TTL**: Default 5,000ms (5 seconds) to prevent deadlocks from crashed processes
  - **Telemetry**: Emits events for lock duration and contention tracking

  ## Usage

      # Acquire a lock with a unique value (e.g., UUID)
      lock_value = UUID.uuid4()
      case DistributedLock.lock("seat:123", lock_value, 5000) do
        {:ok, ^lock_value} ->
          # Critical section - you own the lock
          perform_seat_reservation()

          # Always unlock when done
          DistributedLock.unlock("seat:123", lock_value)

        {:error, :lock_unavailable} ->
          # Lock is held by another process
          {:error, :seat_locked}
      end

  ## Safety Guarantees

  1. **Atomicity**: Lock acquisition is atomic via Redis SET NX
  2. **Ownership**: Only the process holding the lock value can unlock it
  3. **Auto-expiry**: Locks automatically expire after TTL to prevent deadlocks
  4. **Idempotency**: Unlocking with wrong value is safe (no-op)

  ## Telemetry Events

  - `[:distributed_lock, :acquired]` - Lock successfully acquired
  - `[:distributed_lock, :failed]` - Lock acquisition failed (contention)
  - `[:distributed_lock, :released]` - Lock successfully released
  - `[:distributed_lock, :expired]` - Lock expired (not explicitly released)
  """

  require Logger
  alias Voelgoedevents.Infrastructure.Redis

  @default_ttl_ms 5_000

  # Lua script for safe unlock - only unlock if the value matches
  @unlock_script """
  if redis.call("get", KEYS[1]) == ARGV[1] then
    return redis.call("del", KEYS[1])
  else
    return 0
  end
  """

  @doc """
  Acquires a distributed lock for the given key.

  ## Parameters

  - `key`: Lock identifier (e.g., "seat:123", "order:456")
  - `value`: Unique lock value (e.g., UUID) to identify the lock owner
  - `ttl_ms`: Time-to-live in milliseconds (default: #{@default_ttl_ms}ms)

  ## Returns

  - `{:ok, value}` - Lock acquired successfully
  - `{:error, :lock_unavailable}` - Lock is already held by another process

  ## Examples

      iex> lock_id = "my-process-#{System.unique_integer()}"
      iex> DistributedLock.lock("resource:123", lock_id)
      {:ok, "my-process-123"}

      iex> DistributedLock.lock("resource:123", "another-id")
      {:error, :lock_unavailable}
  """
  @spec lock(String.t(), String.t(), pos_integer()) ::
          {:ok, String.t()} | {:error, :lock_unavailable}
  def lock(key, value, ttl_ms \\ @default_ttl_ms) when is_binary(key) and is_binary(value) do
    start_time = System.monotonic_time()

    # Use Redis SET with NX (only set if not exists) and PX (TTL in milliseconds)
    # This is an atomic operation
    case Redis.command(["SET", key, value, "NX", "PX", to_string(ttl_ms)]) do
      {:ok, "OK"} ->
        duration = System.monotonic_time() - start_time

        emit_telemetry(:acquired, %{
          key: key,
          ttl_ms: ttl_ms,
          duration: duration
        })

        Logger.debug("Lock acquired: #{key} (ttl: #{ttl_ms}ms)")
        {:ok, value}

      {:ok, nil} ->
        duration = System.monotonic_time() - start_time

        emit_telemetry(:failed, %{
          key: key,
          duration: duration,
          reason: :lock_unavailable
        })

        Logger.debug("Lock unavailable: #{key}")
        {:error, :lock_unavailable}

      {:error, reason} ->
        Logger.error("Redis error during lock acquisition: #{inspect(reason)}")
        {:error, :lock_unavailable}
    end
  end

  @doc """
  Releases a distributed lock.

  Uses a Lua script to ensure only the lock owner (matching value) can release it.
  This prevents a delayed process from accidentally releasing a lock acquired by another process.

  ## Parameters

  - `key`: Lock identifier
  - `value`: The unique value used when acquiring the lock

  ## Returns

  - `:ok` - Lock released successfully or didn't exist
  - `{:error, :not_owner}` - Lock exists but with a different value (caller is not the owner)

  ## Examples

      iex> DistributedLock.lock("resource:123", "my-lock-id")
      {:ok, "my-lock-id"}
      iex> DistributedLock.unlock("resource:123", "my-lock-id")
      :ok

      iex> DistributedLock.unlock("resource:123", "wrong-id")
      {:error, :not_owner}
  """
  @spec unlock(String.t(), String.t()) :: :ok | {:error, :not_owner}
  def unlock(key, value) when is_binary(key) and is_binary(value) do
    start_time = System.monotonic_time()

    # Execute Lua script: EVAL script numkeys key [key ...] arg [arg ...]
    # KEYS[1] = key
    # ARGV[1] = value
    case Redis.command(["EVAL", @unlock_script, "1", key, value]) do
      {:ok, 1} ->
        duration = System.monotonic_time() - start_time

        emit_telemetry(:released, %{
          key: key,
          duration: duration
        })

        Logger.debug("Lock released: #{key}")
        :ok

      {:ok, 0} ->
        # Lock either doesn't exist or has different value
        Logger.debug("Lock release failed (not owner or expired): #{key}")
        {:error, :not_owner}

      {:error, reason} ->
        Logger.error("Redis error during lock release: #{inspect(reason)}")
        {:error, :not_owner}
    end
  end

  @doc """
  Executes a function while holding a distributed lock.

  Automatically acquires the lock, executes the function, and releases the lock.
  If the lock cannot be acquired, returns an error without executing the function.

  ## Parameters

  - `key`: Lock identifier
  - `ttl_ms`: Time-to-live in milliseconds (default: #{@default_ttl_ms}ms)
  - `fun`: Zero-arity function to execute while holding the lock

  ## Returns

  - `{:ok, result}` - Function executed successfully, returns function result
  - `{:error, :lock_unavailable}` - Could not acquire lock

  ## Examples

      iex> DistributedLock.with_lock("seat:123", 5000, fn ->
      ...>   # Critical section - reserve seat
      ...>   reserve_seat(123)
      ...> end)
      {:ok, %Seat{id: 123, status: :reserved}}

      iex> DistributedLock.with_lock("seat:123", 5000, fn ->
      ...>   # Won't execute if lock is held elsewhere
      ...> end)
      {:error, :lock_unavailable}
  """
  @spec with_lock(String.t(), pos_integer(), (-> any())) ::
          {:ok, any()} | {:error, :lock_unavailable}
  def with_lock(key, ttl_ms \\ @default_ttl_ms, fun) when is_function(fun, 0) do
    # Generate unique lock value
    lock_value = generate_lock_value()

    case lock(key, lock_value, ttl_ms) do
      {:ok, ^lock_value} ->
        try do
          result = fun.()
          {:ok, result}
        after
          # Always release the lock, even if function raises
          unlock(key, lock_value)
        end

      {:error, :lock_unavailable} = error ->
        error
    end
  end

  # Private Helpers

  defp generate_lock_value do
    # Generate a unique lock identifier
    # Using node name + process ID + monotonic time for uniqueness
    node_id = :erlang.phash2(node())
    pid_id = :erlang.phash2(self())
    timestamp = System.unique_integer([:positive, :monotonic])

    "#{node_id}:#{pid_id}:#{timestamp}"
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:distributed_lock, event],
      %{count: 1, duration: Map.get(metadata, :duration, 0)},
      metadata
    )
  end
end
