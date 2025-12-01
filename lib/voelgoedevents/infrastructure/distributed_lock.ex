defmodule Voelgoedevents.Infrastructure.DistributedLock do
  @moduledoc """
  Distributed Lock Manager (DLM) using Redis SET NX/PX.
  CRITICAL for preventing overselling (Phase 1.3.6).

  ## Architecture
  - Uses Redis STRING data structure with SET key value NX PX timeout
  - NX: Only set if key does NOT exist (atomic test-and-set)
  - PX: Auto-expire after timeout_ms (prevents deadlock if holder crashes)
  - Unique client ID (node + PID) prevents cross-node unlocking

  ## Safety Guarantees
  - Atomic acquisition via Redis SET NX
  - Safe release via Lua script (checks client ID before DEL)
  - Auto-expiry prevents orphaned locks
  """

  alias Voelgoedevents.Infrastructure.Redis

  # Lua script for safe unlock: Only delete if the value matches our client ID
  # This prevents Node A from unlocking Node B's lock
  @unlock_script """
  if redis.call("GET", KEYS[1]) == ARGV[1] then
    return redis.call("DEL", KEYS[1])
  else
    return 0
  end
  """

  @doc """
  Acquires a distributed lock using Redis SET NX PX.

  ## Parameters
  - `key`: Lock identifier (e.g., "lock:seat:123")
  - `timeout_ms`: Lock expiration in milliseconds (auto-release if holder crashes)

  ## Returns
  - `true`: Lock acquired successfully
  - `false`: Lock is already held by another process/node
  - `{:error, reason}`: Redis communication error

  ## Examples

      iex> lock("lock:seat:42", 5000)
      true

      iex> lock("lock:seat:42", 5000)
      false  # Already locked

  """
  @spec lock(binary(), non_neg_integer()) :: boolean() | {:error, atom()}
  def lock(key, timeout_ms) when is_binary(key) and is_integer(timeout_ms) and timeout_ms > 0 do
    client_id = generate_client_id()

    # Redis SET key value NX PX timeout_ms
    # Returns "OK" if acquired, nil if already exists
    case Redis.command(["SET", key, client_id, "NX", "PX", timeout_ms]) do
      {:ok, "OK"} ->
        # Store client ID in process dictionary for unlock
        Process.put({__MODULE__, key}, client_id)
        true

      {:ok, nil} ->
        # Lock already held
        false

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Releases a distributed lock using a Lua script for atomic verification.

  ## Safety
  This function uses a Lua script to atomically:
  1. Check if the lock value matches our client ID
  2. Delete the lock ONLY if it matches

  This prevents Node A from accidentally unlocking Node B's lock.

  ## Parameters
  - `key`: Lock identifier (must match the key used in lock/2)

  ## Returns
  - `:ok`: Lock released successfully (or was already released/expired)
  - `{:error, :not_owner}`: Lock is held by a different process/node
  - `{:error, reason}`: Redis communication error

  ## Examples

      iex> lock("lock:seat:42", 5000)
      true
      iex> unlock("lock:seat:42")
      :ok

  """
  @spec unlock(binary()) :: :ok | {:error, atom()}
  def unlock(key) when is_binary(key) do
    # Retrieve the client ID we stored during lock acquisition
    client_id = Process.get({__MODULE__, key})

    if client_id do
      # Use EVAL to run the Lua script atomically
      # EVAL script numkeys key [key ...] arg [arg ...]
      case Redis.command(["EVAL", @unlock_script, 1, key, client_id]) do
        {:ok, 1} ->
          # Lock was deleted (we were the owner)
          Process.delete({__MODULE__, key})
          :ok

        {:ok, 0} ->
          # Lock value didn't match (someone else holds it, or it expired)
          Process.delete({__MODULE__, key})
          {:error, :not_owner}

        {:error, reason} ->
          {:error, reason}
      end
    else
      # No client_id in process dictionary - we never acquired this lock
      {:error, :not_owner}
    end
  end

  # Generates a unique client identifier to prevent cross-node unlocking
  # Format: "node@host:pid"
  # Example: "voelgoed@server1:0.123.0"
  @spec generate_client_id() :: binary()
  defp generate_client_id do
    "#{Node.self()}:#{inspect(self())}"
  end
end
