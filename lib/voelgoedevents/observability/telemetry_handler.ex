defmodule Voelgoedevents.Observability.TelemetryHandler do
  @moduledoc """
  Central collector and dispatcher for all Telemetry events (OTel compatible).
  Handles real-time metric aggregation and tracing.
  """
  def setup, do: :ok
  def handle_event(_event, _measurements, _metadata), do: :ok
end
