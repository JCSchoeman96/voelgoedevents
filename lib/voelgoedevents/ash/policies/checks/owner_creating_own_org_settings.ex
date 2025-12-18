defmodule Voelgoedevents.Ash.Policies.Checks.OwnerCreatingOwnOrgSettings do
  @moduledoc false

  use Ash.Policy.SimpleCheck

  @impl true
  def describe(_opts), do: "owner can only create org settings for their own organization"

  @impl true
  def match?(actor, %{subject: %Ash.Changeset{} = changeset}, _opts) do
    actor_org_id = Map.get(actor || %{}, :organization_id)
    actor_role = Map.get(actor || %{}, :role)
    changeset_org_id = Ash.Changeset.get_attribute(changeset, :organization_id)

    actor_role == :owner and not is_nil(actor_org_id) and changeset_org_id == actor_org_id
  end
end
