defmodule Voelgoedevents.Ash.Resources.Audit.AuditLog do
  @moduledoc "Ash resource: Immutable audit log entry."

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

      change change_attribute(:organization_id, actor(:organization_id))
    end

    read :read
  end

  policies do
    # FIX: Replaced failing TenantPolicies.enforce_tenant_policies()
    # with explicit policies to avoid macro variable hygiene errors.

    policy action_type(:read) do
      description "Users can only read audit logs for their organization."
      forbid_if expr(organization_id != actor(:organization_id))
      authorize_if always()
    end
  end
end
