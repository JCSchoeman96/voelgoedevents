defmodule Voelgoedevents.Infrastructure.EtsRegistry do
  @moduledoc """
  Supervisor-owned ETS registry for hot-layer tables.

  Tables:
  - `:seat_holds_hot` — mirrors active holds for microsecond reads. Use short TTLs (1–5 minutes) and purge entries whenever holds are written through to Redis/Postgres.
  - `:recent_scans` — deduplicates scans. Keep entries very short-lived (seconds to 1 minute) and clear on scan write-through.
  - `:pricing_cache` — stores pricing snapshots. Keep TTLs to 1–5 minutes and invalidate on any pricing rule update before recomputing Redis.
  - `:rbac_cache` — caches membership/permission lookups. Use explicit invalidation on role changes and keep TTLs short (1–5 minutes).

  All tables are node-local, `:public` named `:set` tables with read/write concurrency enabled. Callers **must** clear or refresh ETS entries whenever the corresponding Redis or database records change to keep the hot layer aligned with the warm layer.
  """

  use GenServer

  @tables [
    :seat_holds_hot,
    :recent_scans,
    :pricing_cache,
    :rbac_cache
  ]

  @doc "Starts the registry under a supervisor."
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      shutdown: 5000,
      type: :worker
    }
  end

  @doc "Starts the ETS registry process." # credo:disable-for-next-line Credo.Check.Readability.Specs
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Enum.each(@tables, &create_table/1)

    {:ok, MapSet.new(@tables)}
  end

  defp create_table(name) do
    case :ets.whereis(name) do
      :undefined ->
        :ets.new(name, [:set, :public, :named_table, read_concurrency: true, write_concurrency: true])
        :ok

      table when is_reference(table) ->
        :ets.delete(table)
        :ets.new(name, [:set, :public, :named_table, read_concurrency: true, write_concurrency: true])
        :ok
    end
  end
end
