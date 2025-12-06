defmodule Voelgoedevents.Ash.Resources.Organizations.OrganizationSettings do
  @moduledoc "Ash resource: Organization settings."

  alias Ash.Query
  alias Voelgoedevents.Ash.Policies.PlatformPolicy

  require PlatformPolicy
  require Ash.Query

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

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
  read :read do
    prepare fn query, %{actor: actor} = _context ->
      cond do
        # 1) Super admin: unrestricted
        Map.get(actor, :role) == :super_admin ->
          query

        # 2) Platform admin: unrestricted
        Map.get(actor, :is_platform_admin) == true ->
          query

        # 3) Normal actor: scope to their organization_id
        organization_id = Map.get(actor, :organization_id) ->
          Query.filter(query, organization_id == ^organization_id)

        # 4) No actor / no org: return no rows
        true ->
          Query.filter(query, false)
      end
    end
  end

  create :create do
    primary? true

    accept [:currency, :timezone, :primary_color, :logo_url, :organization_id]

    change relate_actor(:organization)
  end

  update :update do
    accept [:currency, :timezone, :primary_color, :logo_url]
  end
end


  policies do
    PlatformPolicy.platform_admin_root_access()

    policy action_type([:read, :create, :update]) do
      forbid_if expr(is_nil(actor(:id)))
    end

    policy action_type(:create) do
      forbid_if expr(actor(:role) != :super_admin and organization_id != actor(:organization_id))
      authorize_if always()
    end

    policy action_type([:read, :update]) do
      forbid_if expr(not (organization_id == actor(:organization_id) or actor(:role) == :super_admin))
      authorize_if always()
    end
  end
end
