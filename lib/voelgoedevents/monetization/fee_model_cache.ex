defmodule Voelgoedevents.Monetization.FeeModelCache do
  @moduledoc """
  GenServer responsible for maintaining the HOT (ETS) cache of active FeeModels
  per organization for sub-10ms lookup during checkout (Warm Tier: Redis).
  """
  use GenServer

  # FIX: Added required init/1 callback
  @impl true
  def init(_opts) do
    # This will be implemented later in Phase 21 for real caching setup
    {:ok, :not_implemented}
  end

  # GenServer callbacks and ETS operations
  def get_active_model(_organization_id), do: :not_implemented
end
