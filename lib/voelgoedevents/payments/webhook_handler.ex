defmodule Voelgoedevents.Payments.WebhookHandler do
  @moduledoc "Endpoint for processing asynchronous notifications from payment gateways."
  def handle_webhook(_gateway, _payload), do: :ok # Oban job likely spawned here
end
