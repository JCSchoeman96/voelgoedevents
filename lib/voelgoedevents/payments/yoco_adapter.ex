defmodule Voelgoedevents.Payments.YocoAdapter do
  @moduledoc "Payment provider adapter for Yoco (South Africa)."
  # @behaviour Voelgoedevents.Contracts.Payments.PaymentProvider

  def charge(_transaction, _amount_cents, _payment_token), do: {:error, :not_implemented}
end
