defmodule Voelgoedevents.Ash.Resources.Audit.AuditLog do
  @moduledoc "Ash resource: Immutable audit log entry."

  alias Voelgoedevents.Ash.Policies.TenantPolicies

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

      change set_attribute(:organization_id, actor(:organization_id))
    end

    read :read
  end

  policies do
    TenantPolicies.enforce_tenant_policies()
  end
end
