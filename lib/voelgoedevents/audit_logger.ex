defmodule Voelgoedevents.AuditLogger do
  @moduledoc "Lightweight audit logger for security-sensitive events."

  require Logger

  @spec log_critical(map()) :: :ok
  def log_critical(attributes) when is_map(attributes) do
    payload =
      attributes
      |> Map.put_new(:severity, :critical)
      |> Map.put_new(:timestamp, DateTime.utc_now())

    :telemetry.execute([:voelgoedevents, :audit, :log], %{count: 1}, payload)

    Logger.error("audit_log", audit: payload)

    :ok
  end
end
