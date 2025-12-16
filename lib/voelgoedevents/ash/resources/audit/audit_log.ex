defmodule Voelgoedevents.Ash.Resources.Audit.AuditLog do
  @moduledoc """
  Ash resource: Immutable audit log entry.

  NOTE: Does NOT use Voelgoedevents.Ash.Resources.Base to avoid recursive auditing via AuditChange.
  Tenant isolation is enforced via explicit policies.
  """

  # Removed the failing macro call context
  # require Voelgoedevents.Ash.Policies.TenantPolicies

  use Ash.Resource,
    domain: Voelgoedevents.Ash.Domains.AuditDomain,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "audit_logs"
    repo Voelgoedevents.Repo
  end

  attributes do
    uuid_primary_key :id

    attribute :actor_id, :uuid do
      allow_nil? false
    end

    attribute :action, :string do
      allow_nil? false
    end

    attribute :resource, :string do
      allow_nil? false
    end

    attribute :resource_id, :string do
      allow_nil? false
    end

    attribute :changes, :map do
      allow_nil? false
      sensitive? true
    end

    attribute :organization_id, :uuid do
      allow_nil? true
    end

    timestamps()
  end

  actions do
    defaults []

    create :create do
      accept [:actor_id, :action, :resource, :resource_id, :changes, :organization_id]

      change &__MODULE__.set_organization_from_actor/2
    end

    read :read
  end

  policies do
    # FIX: Replaced failing TenantPolicies.enforce_tenant_policies()
    # with explicit policies to avoid macro variable hygiene errors.

    policy action_type(:read) do
      description "Users can only read audit logs for their organization."
      forbid_if expr(organization_id != ^actor(:organization_id))
      authorize_if always()
    end
  end

  def set_organization_from_actor(changeset, context) do
    # Ash 3.x: context is a struct, use Map.get/2 for safe access
    actor = Map.get(context, :actor)

    case actor do
      # Extract org_id from actor (works for user, device, system actors)
      %{organization_id: org_id} when not is_nil(org_id) ->
        Ash.Changeset.change_attribute(changeset, :organization_id, org_id)

      # No actor or no org context
      _ ->
        changeset
    end
  end
end
