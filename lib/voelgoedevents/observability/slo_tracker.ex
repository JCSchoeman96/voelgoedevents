defmodule Voelgoedevents.Observability.SLOTracker do
  @moduledoc """
  Tracks Service Level Objectives (SLOs) and Error Budgets for critical workflows
  like Checkout Success Rate and Scan Latency (Phase 1.3.9).

  This module maintains high-performance metrics using ETS for tracking:
  - Success/failure counts per domain and metric
  - Error budget calculations
  - Real-time aggregation without database overhead

  ## Architecture Rule
  This is a passive collector - it stores metrics but does NOT contain business logic
  or directly mutate Ash/Postgres/Redis.

  ## Usage

      # Track successful operations
      SLOTracker.track_success(:checkout, :api_latency)
      SLOTracker.track_success(:scanning, :scan_p99)

      # Track failures
      SLOTracker.track_failure(:checkout, :api_latency)

      # Query current metrics
      SLOTracker.get_metrics(:checkout, :api_latency)
      # => %{success: 9900, failure: 100, total: 10000}

      # Calculate error budget
      SLOTracker.calculate_error_budget(:checkout, :api_latency, 99.9)
      # => %{success_rate: 99.0, budget_consumed: 90.0, slo_target: 99.9}
  """

  use GenServer
  require Logger

  @table :slo_metrics

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Records a successful operation for the given domain and metric.

  ## Parameters
  - `domain`: Atom representing the domain (e.g., `:checkout`, `:scanning`, `:api`)
  - `metric`: Atom or string representing the metric (e.g., `:api_latency`, `:checkout_p99`)

  ## Examples

      iex> SLOTracker.track_success(:checkout, :api_latency)
      :ok
  """
  @spec track_success(atom(), atom() | String.t()) :: :ok
  def track_success(domain, metric) when is_atom(domain) do
    metric_key = normalize_metric(metric)
    increment_counter(domain, metric_key, :success)
    :ok
  end

  @doc """
  Records a failed operation for the given domain and metric.

  ## Parameters
  - `domain`: Atom representing the domain (e.g., `:checkout`, `:scanning`, `:api`)
  - `metric`: Atom or string representing the metric (e.g., `:api_latency`, `:checkout_p99`)

  ## Examples

      iex> SLOTracker.track_failure(:checkout, :api_latency)
      :ok
  """
  @spec track_failure(atom(), atom() | String.t()) :: :ok
  def track_failure(domain, metric) when is_atom(domain) do
    metric_key = normalize_metric(metric)
    increment_counter(domain, metric_key, :failure)
    :ok
  end

  @doc """
  Reports a metric event with status and optional duration.

  This is a convenience function that wraps `track_success/2` and `track_failure/2`
  based on the status parameter.

  ## Parameters
  - `metric`: Atom representing the metric (e.g., `:api_latency`, `:checkout_p99`)
  - `status`: Status of the operation (`:success` or `:failure`, or `:ok` / `:error`)
  - `duration`: Optional duration in milliseconds (currently logged but not stored)

  ## Examples

      iex> SLOTracker.report(:api_latency, :success, 150)
      :ok

      iex> SLOTracker.report(:checkout_p99, :failure, 6000)
      :ok

      # Also supports :ok/:error for convenience
      iex> SLOTracker.report(:api_latency, :ok, 100)
      :ok
  """
  @spec report(atom() | String.t(), :success | :failure | :ok | :error, non_neg_integer() | nil) ::
          :ok
  def report(metric, status, duration \\ nil) do
    metric_key = normalize_metric(metric)

    # Determine domain from metric name if possible, otherwise use :system
    domain = infer_domain(metric_key)

    case normalize_status(status) do
      :success ->
        increment_counter(domain, metric_key, :success)
        if duration, do: Logger.debug("Metric reported: #{metric_key} succeeded in #{duration}ms")

      :failure ->
        increment_counter(domain, metric_key, :failure)

        if duration,
          do: Logger.warning("Metric reported: #{metric_key} failed after #{duration}ms")
    end

    :ok
  end

  @doc """
  Retrieves current metrics for a specific domain and metric.

  Returns a map with success, failure, and total counts.

  ## Examples

      iex> SLOTracker.get_metrics(:checkout, :api_latency)
      %{success: 1000, failure: 10, total: 1010}
  """
  @spec get_metrics(atom(), atom() | String.t()) :: %{
          success: non_neg_integer(),
          failure: non_neg_integer(),
          total: non_neg_integer()
        }
  def get_metrics(domain, metric) when is_atom(domain) do
    metric_key = normalize_metric(metric)
    success = get_counter(domain, metric_key, :success)
    failure = get_counter(domain, metric_key, :failure)

    %{
      success: success,
      failure: failure,
      total: success + failure
    }
  end

  @doc """
  Calculates the error budget consumption for a given domain and metric.

  ## Parameters
  - `domain`: Atom representing the domain
  - `metric`: Atom or string representing the metric
  - `slo_target`: Target SLO percentage (e.g., 99.9 for 99.9%)

  ## Returns
  A map containing:
  - `success_rate`: Current success rate percentage
  - `budget_consumed`: Percentage of error budget consumed
  - `slo_target`: The target SLO percentage

  ## Examples

      iex> SLOTracker.calculate_error_budget(:checkout, :api_latency, 99.9)
      %{success_rate: 99.5, budget_consumed: 50.0, slo_target: 99.9}
  """
  @spec calculate_error_budget(atom(), atom() | String.t(), float()) :: %{
          success_rate: float(),
          budget_consumed: float(),
          slo_target: float()
        }
  def calculate_error_budget(domain, metric, slo_target)
      when is_atom(domain) and is_float(slo_target) do
    metrics = get_metrics(domain, metric)

    success_rate =
      if metrics.total > 0 do
        metrics.success / metrics.total * 100.0
      else
        100.0
      end

    # Error budget is the allowed failure rate
    # e.g., 99.9% SLO = 0.1% allowed failure rate
    allowed_failure_rate = 100.0 - slo_target
    actual_failure_rate = 100.0 - success_rate

    budget_consumed =
      if allowed_failure_rate > 0 do
        actual_failure_rate / allowed_failure_rate * 100.0
      else
        0.0
      end

    %{
      success_rate: Float.round(success_rate, 2),
      budget_consumed: Float.round(budget_consumed, 2),
      slo_target: slo_target
    }
  end

  @doc """
  Resets all metrics for a specific domain and metric (useful for testing).
  """
  @spec reset_metrics(atom(), atom() | String.t()) :: :ok
  def reset_metrics(domain, metric) when is_atom(domain) do
    metric_key = normalize_metric(metric)
    :ets.delete(@table, {domain, metric_key, :success})
    :ets.delete(@table, {domain, metric_key, :failure})
    :ok
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting SLOTracker with ETS table #{@table}")

    # Create ETS table for high-performance metric storage
    # Using :set for unique keys, :public for read access from other processes
    # :write_concurrency for high-throughput writes
    :ets.new(@table, [
      :named_table,
      :set,
      :public,
      {:read_concurrency, true},
      {:write_concurrency, true}
    ])

    {:ok, %{}}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.info("SLOTracker terminating: #{inspect(reason)}")
    :ok
  end

  # Private Functions

  defp normalize_metric(metric) when is_atom(metric), do: metric
  defp normalize_metric(metric) when is_binary(metric), do: String.to_atom(metric)

  defp normalize_status(:success), do: :success
  defp normalize_status(:ok), do: :success
  defp normalize_status(:failure), do: :failure
  defp normalize_status(:error), do: :failure
  defp normalize_status(other), do: raise(ArgumentError, "Invalid status: #{inspect(other)}")

  defp infer_domain(metric) do
    # Infer domain from metric name patterns
    metric_str = to_string(metric)

    cond do
      String.contains?(metric_str, "checkout") -> :checkout
      String.contains?(metric_str, "api") -> :api
      String.contains?(metric_str, "scan") -> :scanning
      String.contains?(metric_str, "circuit") -> :circuit_breaker
      String.contains?(metric_str, "lock") -> :distributed_lock
      String.contains?(metric_str, "web") -> :web
      true -> :system
    end
  end

  defp increment_counter(domain, metric, counter_type) do
    key = {domain, metric, counter_type}

    # Use :ets.update_counter for atomic increment
    # Default to 0 if key doesn't exist, then increment by 1
    try do
      :ets.update_counter(@table, key, {2, 1}, {key, 0})
    rescue
      ArgumentError ->
        # Table might not exist during tests, insert manually
        :ets.insert(@table, {key, 1})
    end
  end

  defp get_counter(domain, metric, counter_type) do
    key = {domain, metric, counter_type}

    case :ets.lookup(@table, key) do
      [{^key, count}] -> count
      [] -> 0
    end
  end
end
