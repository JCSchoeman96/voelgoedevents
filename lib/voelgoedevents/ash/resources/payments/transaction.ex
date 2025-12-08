defmodule Voelgoedevents.Ash.Resources.Payments.Transaction do
  @moduledoc "Ash resource: Payment transaction."

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.PaymentsDomain

  postgres do
    # TODO: configure correct table name
    table "payment_transactions"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :organization_id, :uuid do
      allow_nil? false
    end
  end

  policies do
    # Platform admins have root access
    policy always() do
      authorize_if expr(actor(:is_platform_admin) == true)
    end

    # Read: Allow all authenticated org members
    policy action_type(:read) do
      forbid_if expr(is_nil(actor(:id)))
      authorize_if expr(organization_id == actor(:organization_id))
    end

    # Create/Update/Destroy: Only owner and admin (payment transactions are sensitive)
    policy action_type([:create, :update, :destroy]) do
      forbid_if expr(is_nil(actor(:id)))
      forbid_if expr(organization_id != actor(:organization_id))
      authorize_if expr(actor(:role) in [:owner, :admin])
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end

  # TODO: define relationships, identities, calculations, and changes.
  # See docs/domain/*.md for details.
end
