defmodule Voelgoedevents.Ash.Resources.Payments.LedgerAccount do
  @moduledoc "Ash resource: Ledger accounts."

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.PaymentsDomain

  postgres do
    # TODO: configure correct table name
    table "ledger_accounts"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? false
    end
  end

  # TODO: define relationships, actions, identities, calculations, and changes.
  # See docs/domain/*.md for details.
end
