defmodule Voelgoedevents.Infrastructure.CircuitBreaker do
  @moduledoc """
  A fail-fast Circuit Breaker mechanism to protect the application from cascading failures.

  Uses an ETS table for low-latency state checks and a GenServer for managing
  state transitions and timers.

  ## States
  - `:closed`: Normal operation. Requests are allowed.
  - `:open`: Circuit is tripped. Requests are blocked immediately.
  - `:half_open`: Probation period. One request is allowed to test the service.

  ## Configuration
  Configure in `config/config.exs`:

      config :voelgoedevents, Voelgoedevents.Infrastructure.CircuitBreaker,
        open_failure_count: 5,
        reset_timeout_ms: 60_000

  ## Telemetry Events
  - `[:circuit_breaker, :circuit_opened]` - Circuit opened due to failures
  - `[:circuit_breaker, :circuit_closed]` - Circuit closed after recovery
  - `[:circuit_breaker, :request_failed]` - Individual request failure
  """

  use GenServer
  require Logger

  @table :circuit_breaker_state

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Executes the given function protected by the circuit breaker for the specified service.

  ## Examples

      {:ok, result} = CircuitBreaker.call(:payment_gateway, fn ->
        PaymentAPI.charge(params)
      end)

      {:error, :circuit_open} = CircuitBreaker.call(:payment_gateway, fn ->
        # This won't execute if circuit is open
      end)
  """
  @spec call(atom(), (-> any())) :: {:ok, any()} | {:error, any()}
  def call(service_name, fun) do
    case get_state(service_name) do
      :open ->
        {:error, :circuit_open}

      :closed ->
        execute_request(service_name, fun)

      :half_open ->
        execute_request(service_name, fun)
    end
  end

  @doc """
  Gets the current status of a circuit breaker.

  Returns a map with:
  - `:state` - Current state (`:closed`, `:open`, or `:half_open`)
  - `:failures` - Current failure count
  - `:last_failure` - Timestamp of last failure (if any)
  """
  @spec get_status(atom()) :: map()
  def get_status(service_name) do
    GenServer.call(__MODULE__, {:get_status, service_name})
  end

  # Private Client Functions

  defp execute_request(service_name, fun) do
    try do
      result = fun.()
      report_success(service_name)
      {:ok, result}
    rescue
      e ->
        report_failure(service_name, e)
        {:error, e}
    catch
      :exit, reason ->
        report_failure(service_name, {:exit, reason})
        {:error, {:exit, reason}}
    end
  end

  defp get_state(service_name) do
    case :ets.lookup(@table, {service_name, :state}) do
      [{_, state}] -> state
      [] -> :closed
    end
  end

  defp report_success(service_name) do
    case get_state(service_name) do
      :half_open -> GenServer.cast(__MODULE__, {:success, service_name})
      :closed ->
        case :ets.lookup(@table, {service_name, :failures}) do
          [{_, 0}] -> :ok
          [] -> :ok
          _ -> GenServer.cast(__MODULE__, {:success, service_name})
        end
      _ -> :ok
    end
  end

  defp report_failure(service_name, _error) do
    GenServer.cast(__MODULE__, {:failure, service_name})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    :ets.new(@table, [:named_table, :set, :public, {:read_concurrency, true}])

    config = Application.get_env(:voelgoedevents, __MODULE__, [])

    state = %{
      open_failure_count: Keyword.get(config, :open_failure_count, 5),
      reset_timeout_ms: Keyword.get(config, :reset_timeout_ms, 60_000)
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:get_status, service_name}, _from, state) do
    status = %{
      state: get_state(service_name),
      failures: get_failures(service_name),
      last_failure: get_last_failure(service_name)
    }
    {:reply, status, state}
  end

  @impl true
  def handle_cast({:success, service_name}, state) do
    current_state = get_state(service_name)

    if current_state == :half_open do
      Logger.info("Circuit breaker for #{service_name} closed (recovered).")
      :ets.insert(@table, {{service_name, :state}, :closed})
      :ets.insert(@table, {{service_name, :failures}, 0})

      emit_telemetry(:circuit_closed, %{service: service_name})
    else
      :ets.insert(@table, {{service_name, :failures}, 0})
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:failure, service_name}, state) do
    current_state = get_state(service_name)
    new_failures = get_failures(service_name) + 1

    emit_telemetry(:request_failed, %{
      service: service_name,
      failure_count: new_failures
    })

    cond do
      current_state == :open ->
        {:noreply, state}

      current_state == :half_open ->
        trip_circuit(service_name, state)
        {:noreply, state}

      new_failures >= state.open_failure_count ->
        trip_circuit(service_name, state)
        {:noreply, state}

      true ->
        :ets.insert(@table, {{service_name, :failures}, new_failures})
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:reset_circuit, service_name}, state) do
    if get_state(service_name) == :open do
      Logger.info("Circuit breaker for #{service_name} entering half-open state.")
      :ets.insert(@table, {{service_name, :state}, :half_open})
    end
    {:noreply, state}
  end

  # Private Server Functions

  defp trip_circuit(service_name, state) do
    Logger.warning("Circuit breaker for #{service_name} tripped (OPEN).")
    :ets.insert(@table, {{service_name, :state}, :open})
    :ets.insert(@table, {{service_name, :last_failure}, System.system_time(:second)})

    emit_telemetry(:circuit_opened, %{service: service_name})

    Process.send_after(self(), {:reset_circuit, service_name}, state.reset_timeout_ms)
  end

  defp get_failures(service_name) do
    case :ets.lookup(@table, {service_name, :failures}) do
      [{_, count}] -> count
      [] -> 0
    end
  end

  defp get_last_failure(service_name) do
    case :ets.lookup(@table, {service_name, :last_failure}) do
      [{_, timestamp}] -> timestamp
      [] -> nil
    end
  end

  defp emit_telemetry(event, metadata) do
    :telemetry.execute(
      [:circuit_breaker, event],
      %{count: 1},
      metadata
    )
  end
end
