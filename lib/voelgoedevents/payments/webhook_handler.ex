defmodule Voelgoedevents.Payments.WebhookHandler do
  @moduledoc "Endpoint for processing asynchronous notifications from payment gateways."
  # Oban job likely spawned here
  def handle_webhook(_gateway, _payload), do: :ok
end
