defmodule Voelgoedevents.Ash.Resources.Organizations.OrganizationSettings do
  @moduledoc "Ash resource: Organization settings."

  alias Voelgoedevents.Ash.Policies.PlatformPolicy

  require PlatformPolicy

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain

  postgres do
    table "organization_settings"
    repo Voelgoedevents.Repo
    identity_index_names unique_organization: "organization_settings_organization_id_index"
  end

  attributes do
    uuid_primary_key :id

    attribute :currency, :atom do
      allow_nil? false
      default :ZAR
      constraints one_of: [:ZAR, :USD, :EUR, :GBP]
    end

    attribute :timezone, :string do
      allow_nil? true
    end

    attribute :primary_color, :string do
      allow_nil? true
    end

    attribute :logo_url, :string do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :organization, Voelgoedevents.Ash.Resources.Accounts.Organization do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_organization, [:organization_id]
  end

  actions do
    read :read do
      primary? true
    end

    create :create do
      primary? true
      accept [:currency, :timezone, :primary_color, :logo_url, :organization_id]
    end

    update :update do
      primary? true
      accept [:currency, :timezone, :primary_color, :logo_url]
    end
  end

  policies do
    # Global override: platform admins always pass authorization checks
    PlatformPolicy.platform_admin_root_access()

    # CREATE: Only owner can create settings, and only for their own org.
    policy action(:create) do
      forbid_if expr(is_nil(^actor(:user_id)))

      # Platform admin can create settings for any org (platform scope)
      authorize_if expr(^actor(:is_platform_admin) == true)

      # Tenant owner can only create settings for their own org
      authorize_if Voelgoedevents.Ash.Policies.Checks.OwnerCreatingOwnOrgSettings
    end

    # UPDATE: Only owner can modify settings (record exists, so record filter is fine).
    policy action(:update) do
      forbid_if expr(is_nil(^actor(:user_id)))

      authorize_if expr(
        organization_id == ^actor(:organization_id) and
          ^actor(:role) == :owner
      )
    end

    # READ: Any authenticated member of the organization can read its settings
    # Cross-tenant reads are forbidden by the organization_id check
    policy action_type(:read) do
      forbid_if expr(is_nil(^actor(:user_id)))

      # Tenant isolation: only members of the same org can see its settings
      authorize_if expr(organization_id == ^actor(:organization_id))
    end
  end
end
