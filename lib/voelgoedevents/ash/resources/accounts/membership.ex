defmodule Voelgoedevents.Ash.Resources.Accounts.Membership do
  @moduledoc "Ash resource: Membership linking users to organizations."

  alias Ash.Changeset

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AccountsDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "memberships"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :status, :atom do
      allow_nil? false
      public? true
      constraints one_of: [:active, :inactive]
      default :active
    end

    attribute :invited_at, :utc_datetime do
      public? true
    end

    attribute :joined_at, :utc_datetime do
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :role, Voelgoedevents.Ash.Resources.Accounts.Role do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :user, Voelgoedevents.Ash.Resources.Accounts.User do
      allow_nil? false
      attribute_writable? true
    end

    belongs_to :organization, Voelgoedevents.Ash.Resources.Accounts.Organization do
      allow_nil? false
      attribute_writable? true
    end
  end

  identities do
    identity :unique_user_organization, [:user_id, :organization_id]
  end

  validations do
    validate present([:status, :role_id, :user_id, :organization_id])

    validate fn changeset ->
      status = Changeset.get_attribute(changeset, :status)
      joined_at = Changeset.get_attribute(changeset, :joined_at)

      if status == :active and is_nil(joined_at) do
        Changeset.add_error(changeset, :joined_at, "must be set when activating membership")
      else
        changeset
      end
    end
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:role_id, :status, :invited_at, :joined_at, :user_id, :organization_id]

      change &__MODULE__.maybe_set_invited_at/1
      change &__MODULE__.maybe_set_joined_at/1
    end

    update :update do
      accept [:role_id, :status, :invited_at, :joined_at]

      change &__MODULE__.maybe_set_joined_at/1
    end

    create :invite do
      accept [:role_id, :user_id, :organization_id]

      change set_attribute(:status, :inactive)
      change &__MODULE__.set_invited_at/1
    end

    update :join do
      accept []

      change set_attribute(:status, :active)
      change &__MODULE__.set_joined_at/1
    end

    destroy :remove do
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if expr(organization_id == actor(:organization_id))
    end

    policy action([:create, :invite, :update, :remove]) do
      authorize_if expr(
                    organization_id == actor(:organization_id) and
                      exists(
                        organization.memberships,
                        user_id == actor(:id) and role.name == :owner
                      )
                  )
    end

    policy action(:join) do
      authorize_if expr(user_id == actor(:id) and organization_id == actor(:organization_id))
    end

    default_policy :deny
  end

  def maybe_set_invited_at(changeset) do
    status = Changeset.get_attribute(changeset, :status)

    if status == :inactive and is_nil(Changeset.get_attribute(changeset, :invited_at)) do
      Changeset.set_attribute(changeset, :invited_at, DateTime.utc_now())
    else
      changeset
    end
  end

  def maybe_set_joined_at(changeset) do
    status = Changeset.get_attribute(changeset, :status)
    joined_at = Changeset.get_attribute(changeset, :joined_at)

    cond do
      status == :active and is_nil(joined_at) -> Changeset.set_attribute(changeset, :joined_at, DateTime.utc_now())
      true -> changeset
    end
  end

  def set_invited_at(changeset) do
    Changeset.set_attribute(changeset, :invited_at, DateTime.utc_now())
  end

  def set_joined_at(changeset) do
    Changeset.set_attribute(changeset, :joined_at, DateTime.utc_now())
  end
end
