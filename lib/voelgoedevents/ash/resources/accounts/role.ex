defmodule Voelgoedevents.Ash.Resources.Accounts.Role do
  @moduledoc "Global role definitions for platform-wide RBAC."

  @role_definitions %{
    owner: %{
      display_name: "Owner",
      permissions: [
        "manage_tenant_users",
        "manage_events_and_venues",
        "manage_ticketing_and_pricing",
        "manage_financials",
        "manage_devices",
        "view_full_analytics"
      ]
    },
    admin: %{
      display_name: "Admin",
      permissions: [
        "manage_tenant_users",
        "manage_events_and_venues",
        "manage_ticketing_and_pricing",
        "view_financials",
        "manage_devices",
        "view_full_analytics"
      ]
    },
    staff: %{
      display_name: "Staff",
      permissions: [
        "manage_ticketing_and_pricing",
        "view_orders",
        "view_limited_analytics"
      ]
    },
    viewer: %{
      display_name: "Viewer",
      permissions: ["view_read_only"]
    },
    scanner_only: %{
      display_name: "Scanner Only",
      permissions: ["perform_scans"]
    }
  }

  # Canonical tenant roles
  @allowed_roles Map.keys(@role_definitions)

  @doc "Returns the list of allowed role atoms."
  def allowed_roles, do: @allowed_roles

  alias Voelgoedevents.Ash.Policies.PlatformPolicy

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  require PlatformPolicy

  postgres do
    table "roles"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :atom do
      allow_nil? false
      constraints one_of: @allowed_roles
      public? true
    end

    attribute :display_name, :string do
      allow_nil? false
      public? true
    end

    attribute :permissions, {:array, :string} do
      allow_nil? false
      default []
      public? true
    end

    timestamps()
  end

  identities do
    identity :unique_name, [:name]
  end

  actions do
    # Reads are open; writes are platform-admin only via PlatformPolicy
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :display_name, :permissions]

      change &apply_canonical_role_metadata/2
    end

    update :update do
      require_atomic? false
      accept [:name, :display_name, :permissions]

      change &apply_canonical_role_metadata/2
    end
  end

  policies do
    PlatformPolicy.platform_admin_root_access()

    policy action_type(:read) do
      authorize_if always()
    end
  end

  defp apply_canonical_role_metadata(changeset, _context) do
    case Map.fetch(@role_definitions, Ash.Changeset.get_attribute(changeset, :name)) do
      {:ok, %{display_name: display_name, permissions: permissions}} ->
        changeset
        |> Ash.Changeset.force_change_attribute(:display_name, display_name)
        |> Ash.Changeset.force_change_attribute(:permissions, permissions)

      _ ->
        changeset
    end
  end
end
