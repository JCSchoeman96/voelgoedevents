defmodule Voelgoedevents.Ash.Resources.Accounts.Role do
  @moduledoc "Ash resource: Role definitions (admin, organizer, staff, etc.)."

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Voelgoedevents.Ash.Policies.PlatformPolicy

  require PlatformPolicy

  @allowed_roles [:owner, :admin, :manager, :support, :read_only]
  @display_names %{
    owner: "Owner",
    admin: "Admin",
    manager: "Manager",
    support: "Support",
    read_only: "Read-only"
  }

  postgres do
    table "roles"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :atom do
      allow_nil? false
      public? true
      constraints one_of: @allowed_roles
    end

    attribute :display_name, :string do
      allow_nil? false
      public? true
    end

    attribute :permissions, {:array, :atom} do
      allow_nil? false
      public? true
      default []
    end

    timestamps()
  end

  identities do
    identity :unique_name, [:name]
  end

  validations do
    validate present([:name, :display_name])
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:name, :display_name, :permissions]
      change &__MODULE__.ensure_display_name/1
      require_actor? true
    end

    update :update do
      accept [:display_name, :permissions]
      require_actor? true
    end
  end

  policies do
    PlatformPolicy.platform_admin_root_access()

    policy action([:create, :update]) do
      authorize_if expr(actor(:role) in [:super_admin, :system])
    end

    policy action_type(:read) do
      authorize_if always()
    end
  end

  def ensure_display_name(changeset) do
    case Ash.Changeset.get_attribute(changeset, :display_name) do
      nil ->
        name = Ash.Changeset.get_attribute(changeset, :name)
        display_name = default_display_name(name)

        Ash.Changeset.force_change_attribute(changeset, :display_name, display_name)

      _display_name ->
        changeset
    end
  end

  def default_display_name(nil), do: nil

  def default_display_name(role) when is_atom(role) do
    Map.get(@display_names, role, role |> Atom.to_string() |> String.capitalize())
  end
end
