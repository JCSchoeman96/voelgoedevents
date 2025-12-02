defmodule Voelgoedevents.Observability.TelemetryHandler do
  @moduledoc """
  Central collector and dispatcher for all Telemetry events (OTel compatible).
  Handles real-time metric aggregation and tracing.

  This module attaches to Elixir's `:telemetry` events and forwards them to
  logging, monitoring backends, and the SLOTracker for error budget calculations.

  ## Architecture Rule
  This is a passive collector - it observes events but does NOT contain business logic
  or directly mutate Ash/Postgres/Redis.

  ## Supported Events

  ### Circuit Breaker Events
  - `[:circuit_breaker, :circuit_opened]` - Circuit breaker tripped
  - `[:circuit_breaker, :circuit_closed]` - Circuit breaker recovered
  - `[:circuit_breaker, :request_failed]` - Individual request failure

  ### Checkout Events (Future)
  - `[:checkout, :started]` - Checkout flow initiated
  - `[:checkout, :completed]` - Checkout flow completed successfully
  - `[:checkout, :failed]` - Checkout flow failed

  ### API Events (Future)
  - `[:api, :request, :start]` - API request started
  - `[:api, :request, :stop]` - API request completed

  ## Usage

      # Called once during application startup
      TelemetryHandler.setup()

      # Events are automatically handled when emitted via :telemetry.execute/3
  """

  require Logger
  alias Voelgoedevents.Observability.SLOTracker

  @events_to_handle [
    # Circuit Breaker Events
    [:circuit_breaker, :circuit_opened],
    [:circuit_breaker, :circuit_closed],
    [:circuit_breaker, :request_failed],

    # Distributed Lock Events
    [:distributed_lock, :acquired],
    [:distributed_lock, :failed],
    [:distributed_lock, :released],

    # Web Request Events
    [:web, :request, :stop],

    # Checkout Events (placeholders for future)
    [:checkout, :started],
    [:checkout, :completed],
    [:checkout, :failed],

    # API Events (placeholders for future)
    [:api, :request, :stop]
  ]

  @doc """
  Attaches telemetry event handlers for all supported events.

  This function should be called once during application startup,
  typically after the supervision tree has started.

  ## Examples

      iex> TelemetryHandler.setup()
      :ok
  """
  @spec setup() :: :ok
  def setup do
    Logger.info("Attaching TelemetryHandler to #{length(@events_to_handle)} event types")

    # Attach a single handler for all events
    :telemetry.attach_many(
      "voelgoedevents-observability-handler",
      @events_to_handle,
      &__MODULE__.handle_event/4,
      %{}
    )

    :ok
  end

  @doc """
  Detaches all telemetry event handlers (useful for testing).

  ## Examples

      iex> TelemetryHandler.teardown()
      :ok
  """
  @spec teardown() :: :ok
  def teardown do
    :telemetry.detach("voelgoedevents-observability-handler")
    :ok
  end

  @doc """
  Handles telemetry events and forwards them to appropriate handlers.

  This callback is invoked by the `:telemetry` library whenever a matching
  event is executed.

  ## Parameters
  - `event`: List representing the event name (e.g., `[:circuit_breaker, :circuit_opened]`)
  - `measurements`: Map of numeric measurements (e.g., `%{count: 1, duration: 500}`)
  - `metadata`: Map of additional context (e.g., `%{service: :payment_gateway}`)
  - `config`: Handler configuration (currently unused)
  """
  @spec handle_event(list(), map(), map(), map()) :: :ok
  def handle_event(event, measurements, metadata, _config) do
    case event do
      [:circuit_breaker, :circuit_opened] ->
        handle_circuit_opened(measurements, metadata)

      [:circuit_breaker, :circuit_closed] ->
        handle_circuit_closed(measurements, metadata)

      [:circuit_breaker, :request_failed] ->
        handle_request_failed(measurements, metadata)

      [:distributed_lock, :acquired] ->
        handle_lock_acquired(measurements, metadata)

      [:distributed_lock, :failed] ->
        handle_lock_failed(measurements, metadata)

      [:distributed_lock, :released] ->
        handle_lock_released(measurements, metadata)

      [:web, :request, :stop] ->
        handle_web_request(measurements, metadata)

      [:checkout, :started] ->
        handle_checkout_started(measurements, metadata)

      [:checkout, :completed] ->
        handle_checkout_completed(measurements, metadata)

      [:checkout, :failed] ->
        handle_checkout_failed(measurements, metadata)

      [:api, :request, :stop] ->
        handle_api_request(measurements, metadata)

      _ ->
        Logger.debug("Unhandled telemetry event: #{inspect(event)}")
    end

    :ok
  end

  # Private Event Handlers

  defp handle_circuit_opened(_measurements, metadata) do
    service = Map.get(metadata, :service, :unknown)

    Logger.warning("Circuit breaker OPENED for service: #{service}",
      service: service,
      event: :circuit_opened
    )

    # Track as failure for SLO
    SLOTracker.track_failure(:circuit_breaker, service)
  end

  defp handle_circuit_closed(_measurements, metadata) do
    service = Map.get(metadata, :service, :unknown)

    Logger.info("Circuit breaker CLOSED for service: #{service}",
      service: service,
      event: :circuit_closed
    )

    # Track recovery as success
    SLOTracker.track_success(:circuit_breaker, service)
  end

  defp handle_request_failed(measurements, metadata) do
    service = Map.get(metadata, :service, :unknown)
    failure_count = Map.get(metadata, :failure_count, 0)

    Logger.warning(
      "Request failed for service: #{service} (failure count: #{failure_count})",
      service: service,
      failure_count: failure_count,
      measurements: measurements
    )

    # Track individual failure
    SLOTracker.track_failure(:circuit_breaker, service)
  end

  defp handle_checkout_started(measurements, metadata) do
    Logger.debug("Checkout started",
      measurements: measurements,
      metadata: metadata
    )

    # Future: Start latency tracking
  end

  defp handle_checkout_completed(measurements, metadata) do
    duration_ms = Map.get(measurements, :duration, 0)

    Logger.info("Checkout completed successfully (duration: #{duration_ms}ms)",
      duration_ms: duration_ms,
      metadata: metadata
    )

    SLOTracker.track_success(:checkout, :checkout_p99)

    # Track latency against SLO (p99 < 5000ms)
    if duration_ms > 5000 do
      Logger.warning("Checkout exceeded p99 SLO target (#{duration_ms}ms > 5000ms)")
      SLOTracker.track_failure(:checkout, :api_latency)
    else
      SLOTracker.track_success(:checkout, :api_latency)
    end
  end

  defp handle_checkout_failed(measurements, metadata) do
    reason = Map.get(metadata, :reason, :unknown)

    Logger.error("Checkout failed",
      reason: reason,
      measurements: measurements,
      metadata: metadata
    )

    SLOTracker.track_failure(:checkout, :checkout_p99)
  end

  defp handle_api_request(measurements, metadata) do
    duration = Map.get(measurements, :duration, 0)
    # Convert from native time unit to milliseconds
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)

    route = Map.get(metadata, :route, :unknown)

    Logger.debug("API request completed",
      route: route,
      duration_ms: duration_ms
    )

    # Track API latency
    if duration_ms > 1000 do
      # Consider requests > 1s as slow
      SLOTracker.track_failure(:api, :api_latency)
    else
      SLOTracker.track_success(:api, :api_latency)
    end
  end

  defp handle_lock_acquired(measurements, metadata) do
    key = Map.get(metadata, :key, :unknown)
    ttl_ms = Map.get(metadata, :ttl_ms, 0)
    duration = Map.get(measurements, :duration, 0)

    Logger.debug("Distributed lock acquired: #{key} (ttl: #{ttl_ms}ms)",
      key: key,
      ttl_ms: ttl_ms,
      acquisition_time: duration
    )

    # Track successful lock acquisition
    SLOTracker.report(:distributed_lock_latency, :success, duration)
  end

  defp handle_lock_failed(measurements, metadata) do
    key = Map.get(metadata, :key, :unknown)
    reason = Map.get(metadata, :reason, :unknown)
    duration = Map.get(measurements, :duration, 0)

    Logger.debug("Distributed lock failed: #{key} (reason: #{reason})",
      key: key,
      reason: reason,
      wait_time: duration
    )

    # Track lock contention
    SLOTracker.report(:distributed_lock_contention, :failure, duration)
  end

  defp handle_lock_released(measurements, metadata) do
    key = Map.get(metadata, :key, :unknown)
    duration = Map.get(measurements, :duration, 0)

    Logger.debug("Distributed lock released: #{key}",
      key: key,
      release_time: duration
    )

    # Track successful release
    SLOTracker.report(:distributed_lock_release, :success, duration)
  end

  defp handle_web_request(measurements, metadata) do
    duration = Map.get(measurements, :duration, 0)
    # Convert from native time unit to milliseconds
    duration_ms = System.convert_time_unit(duration, :native, :millisecond)

    route = Map.get(metadata, :route, :unknown)
    status = Map.get(metadata, :status, :unknown)

    Logger.debug("Web request completed: #{route} (#{status})",
      route: route,
      status: status,
      duration_ms: duration_ms
    )

    # Track web request latency
    metric_status = if status in [200, 201, 204], do: :success, else: :failure
    SLOTracker.report(:web_request_latency, metric_status, duration_ms)

    # Track SLO compliance (p99 < 1000ms)
    if duration_ms > 1000 do
      SLOTracker.report(:web_p99, :failure, duration_ms)
    else
      SLOTracker.report(:web_p99, :success, duration_ms)
    end
  end
end
