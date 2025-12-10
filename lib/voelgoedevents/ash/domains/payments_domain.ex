defmodule Voelgoedevents.Ash.Domains.PaymentsDomain do
  @moduledoc "Ash domain for transactions, refunds, and ledger entries."

  use Ash.Domain

  resources do
    resource Voelgoedevents.Ash.Resources.Payments.Transaction
    resource Voelgoedevents.Ash.Resources.Payments.Refund
    resource Voelgoedevents.Ash.Resources.Payments.LedgerAccount
    resource Voelgoedevents.Ash.Resources.Payments.JournalEntry
  end

  authorization do
    authorizers [Ash.Policy.Authorizer]
  end

  # See docs/domain/*.md for the domain rules.
end
