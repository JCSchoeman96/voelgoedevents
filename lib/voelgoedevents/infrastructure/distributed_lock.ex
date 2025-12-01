defmodule Voelgoedevents.Infrastructure.DistributedLock do
  @moduledoc """
  Distributed Lock Manager (DLM) using Redis SET NX/PX.
  CRITICAL for preventing overselling (Phase 1.3.6).
  """
  # Assumes Redix client connection is configured in the supervision tree.

  @doc "Acquires a lock, returning true/false or {:error, reason}"
  @spec lock(binary(), non_neg_integer()) :: boolean() | {:error, atom()}
  def lock(_key, _timeout_ms), do: :not_implemented

  @doc "Releases a lock. Must use a unique value check to prevent cross-node unlocking."
  @spec unlock(binary()) :: :ok | {:error, atom()}
  def unlock(_key), do: :not_implemented
end
