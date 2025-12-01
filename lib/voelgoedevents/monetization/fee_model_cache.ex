defmodule Voelgoedevents.Monetization.FeeModelCache do
  @moduledoc "GenServer/ETS Cache for fast FeeModel lookup (Hot Data Tier)."
  use GenServer
  def get_active_model(_organization_id), do: :not_implemented
end
