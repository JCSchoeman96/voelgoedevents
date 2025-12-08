defmodule Voelgoedevents.Ash.Resources.Scanning.ScanSession do
  @moduledoc "Ash resource: Scan session."

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.ScanningDomain

  postgres do
    # TODO: configure correct table name
    table "scan_sessions"
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

    # Read: Allow all authenticated org members (including scanners)
    policy action_type(:read) do
      forbid_if expr(is_nil(actor(:id)))
      authorize_if expr(organization_id == actor(:organization_id))
    end

    # Create: Scanners, staff, admin, owner can create scan sessions
    policy action_type(:create) do
      forbid_if expr(is_nil(actor(:id)))
      forbid_if expr(arg(:organization_id) != actor(:organization_id))
      authorize_if expr(actor(:role) in [:owner, :admin, :staff, :scanner])
    end

    # Update: Only staff, admin, owner can update
    policy action_type(:update) do
      forbid_if expr(is_nil(actor(:id)))
      forbid_if expr(organization_id != actor(:organization_id))
      authorize_if expr(actor(:role) in [:owner, :admin, :staff])
    end

    # Destroy: Only admin, owner
    policy action_type(:destroy) do
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
