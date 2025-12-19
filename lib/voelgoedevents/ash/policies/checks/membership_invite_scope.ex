defmodule Voelgoedevents.Ash.Policies.Checks.MembershipInviteScope do
  @moduledoc """
  Enforces tenant scoping for Membership create/invite.

  For create/invite we must compare the actor org against the org_id being written
  (i.e. changeset attribute), not the record (there is no record yet).

  This must return a POLICY denial (Forbidden) when mismatched.
  """

  use Ash.Policy.SimpleCheck

  alias Ash.Changeset

  @impl true
  def describe(_opts), do: "actor org matches membership.organization_id and role is owner/admin"

  @impl true
  def match?(actor, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    actor_type = actor && Map.get(actor, :type)
    actor_org = actor && Map.get(actor, :organization_id)
    actor_role = actor && Map.get(actor, :role)

    target_org = Changeset.get_attribute(changeset, :organization_id)

    actor_type == :user and
      actor_role in [:owner, :admin] and
      not is_nil(actor_org) and
      actor_org == target_org
  end

  def match?(_actor, _context, _opts), do: false
end
