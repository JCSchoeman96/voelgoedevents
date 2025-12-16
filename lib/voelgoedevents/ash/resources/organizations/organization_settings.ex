defmodule Voelgoedevents.Ash.Resources.Organizations.OrganizationSettings do
  @moduledoc "Ash resource: Organization settings."

  alias Voelgoedevents.Ash.Policies.PlatformPolicy

  require PlatformPolicy

  use Voelgoedevents.Ash.Resources.Base,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain

  postgres do
    table "organization_settings"
    repo Voelgoedevents.Repo
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
    read :read

    create :create do
      primary? true

      accept [:currency, :timezone, :primary_color, :logo_url, :organization_id]

      # TODO: relate_actor(:organization) was removed - it incorrectly tried to
      # look up the actor as an Organization. The organization_id is set via
      # manage_relationship from the parent Organization.create action.
    end

    update :update do
      accept [:currency, :timezone, :primary_color, :logo_url]
    end
  end

  policies do
    # Global override: platform admins always pass authorization checks
    PlatformPolicy.platform_admin_root_access()

    # CREATE/UPDATE: Only owner can modify organization settings
    # Settings include financial configuration (currency) which is owner-only per RBAC spec
    policy action_type([:create, :update]) do
      forbid_if expr(is_nil(fact(:actor_user_id)))

      authorize_if expr(
                     organization_id == fact(:actor_org_id) and
                       fact(:actor_role) == :owner
                   )
    end

    # READ: Any authenticated member of the organization can read its settings
    # Cross-tenant reads are forbidden by the organization_id check
    policy action_type(:read) do
      forbid_if expr(is_nil(fact(:actor_user_id)))

      # Tenant isolation: only members of the same org can see its settings
      authorize_if expr(organization_id == fact(:actor_org_id))
    end
  end
end
