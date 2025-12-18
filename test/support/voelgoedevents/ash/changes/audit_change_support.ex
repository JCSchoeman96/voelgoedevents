defmodule Voelgoedevents.Ash.Changes.AuditChangeTest.TestDomain do
  use Ash.Domain, otp_app: :voelgoedevents, validate_config_inclusion?: false

  resources do
    resource Voelgoedevents.Ash.Changes.AuditChangeTest.TestResource
    resource Voelgoedevents.Ash.Changes.AuditChangeTest.SuccessAuditLog
    resource Voelgoedevents.Ash.Changes.AuditChangeTest.FailingAuditLog
  end
end

defmodule Voelgoedevents.Ash.Changes.AuditChangeTest.SuccessAuditLog do
  use Ash.Resource,
    domain: Voelgoedevents.Ash.Changes.AuditChangeTest.TestDomain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
    attribute :actor_id, :uuid, allow_nil?: false
    attribute :action, :string
    attribute :resource, :string
    attribute :resource_id, :string
    attribute :changes, :map
    attribute :organization_id, :uuid
  end

  actions do
    defaults [:read]

    create :create do
      accept [:actor_id, :action, :resource, :resource_id, :changes, :organization_id]
    end
  end
end

defmodule Voelgoedevents.Ash.Changes.AuditChangeTest.FailingAuditLog do
  use Ash.Resource,
    domain: Voelgoedevents.Ash.Changes.AuditChangeTest.TestDomain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
  end

  actions do
    create :create do
      validate fn _changeset, _context -> {:error, "Forced Audit Failure"} end
    end
  end
end

defmodule Voelgoedevents.Ash.Changes.AuditChangeTest.TestResource do
  use Ash.Resource,
    domain: Voelgoedevents.Ash.Changes.AuditChangeTest.TestDomain,
    data_layer: Ash.DataLayer.Ets

  attributes do
    uuid_primary_key :id
    attribute :name, :string
    attribute :organization_id, :uuid, allow_nil?: false
  end

  actions do
    defaults [:read]

    create :create do
      accept [:name, :organization_id]

      change {Voelgoedevents.Ash.Changes.AuditChange,
              [
                audit_resource: Voelgoedevents.Ash.Changes.AuditChangeTest.SuccessAuditLog,
                audit_domain: Voelgoedevents.Ash.Changes.AuditChangeTest.TestDomain
              ]}
    end

    create :create_with_fail do
      accept [:name, :organization_id]

      change {Voelgoedevents.Ash.Changes.AuditChange,
              [
                audit_resource: Voelgoedevents.Ash.Changes.AuditChangeTest.FailingAuditLog,
                audit_domain: Voelgoedevents.Ash.Changes.AuditChangeTest.TestDomain
              ]}
    end
  end
end
