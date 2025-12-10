defmodule Voelgoedevents.Ash.Domains.FinanceDomain do
  @moduledoc """
  DOMAIN: Finance
  Double-entry bookkeeping and financial integrity.
  """
  use Ash.Domain, otp_app: :voelgoedevents

  resources do
    resource Voelgoedevents.Ash.Resources.Finance.Ledger
  end

  authorization do
    authorizers [Ash.Policy.Authorizer]
  end
end
