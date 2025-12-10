defmodule Voelgoedevents.Ash.Domains.MonetizationDomain do
  @moduledoc "Ash domain for monetization logic (fees, donations, policies)."

  use Ash.Domain

  resources do
    resource Voelgoedevents.Ash.Resources.Monetization.Donation
    resource Voelgoedevents.Ash.Resources.Monetization.FeeModel
    resource Voelgoedevents.Ash.Resources.Monetization.FeePolicy
  end

  authorization do
    authorizers [Ash.Policy.Authorizer]
  end
end
