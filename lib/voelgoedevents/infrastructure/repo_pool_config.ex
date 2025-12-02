defmodule Voelgoedevents.Infrastructure.RepoPoolConfig do
  @moduledoc """
  Module to configure dual database pools (Web vs Oban) for high-concurrency 
  isolation, preventing Oban from starving web connections (Phase 1.3.7).
  """
  @spec get_pool_size(binary(), integer()) :: integer()
  def get_pool_size(env_var, default) do
    System.get_env(env_var)
    |> case do
      nil -> default
      val -> String.to_integer(val)
    end
  end
end
