defmodule Voelgoedevents.Ash.Changes.AuditChangeTest do
  @moduledoc """
  Tests for AuditChange behavior, specifically:
  - Verifying the `audit_resource` option (dependency injection).
  - Confirming successful audit log creation.
  - Confirming "fail-closed" behavior (main transaction fails) when audit fails.
  """

  use ExUnit.Case, async: true
  alias Voelgoedevents.Ash.Changes.AuditChange

  # Minimal domain for testing
  defmodule TestDomain do
    use Ash.Domain,
      resources: [
        Voelgoedevents.Ash.Changes.AuditChangeTest.TestResource,
        Voelgoedevents.Ash.Changes.AuditChangeTest.SuccessAuditLog,
        Voelgoedevents.Ash.Changes.AuditChangeTest.FailingAuditLog
      ]
  end

  # ETS-backed AuditLog for success case
  defmodule SuccessAuditLog do
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

  # ETS-backed AuditLog for failure case
  defmodule FailingAuditLog do
    use Ash.Resource,
      domain: Voelgoedevents.Ash.Changes.AuditChangeTest.TestDomain,
      data_layer: Ash.DataLayer.Ets

    attributes do
        number_primary_key :id  # Wrong type maybe? Or just validation fail.
    end

    actions do
      create :create do
         # Force strict failure
         validate fn _changeset, _context -> {:error, "Forced Audit Failure"} end
      end
    end
  end

  # Test resource that uses the AuditChange
  defmodule TestResource do
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
        # Inject the change targeting SuccessAuditLog
        change {Voelgoedevents.Ash.Changes.AuditChange,
          [
            audit_resource: Voelgoedevents.Ash.Changes.AuditChangeTest.SuccessAuditLog,
            audit_domain: Voelgoedevents.Ash.Changes.AuditChangeTest.TestDomain
          ]}
      end

      create :create_with_fail do
        accept [:name, :organization_id]
        # Inject the change targeting FailingAuditLog
        change {Voelgoedevents.Ash.Changes.AuditChange,
          [
            audit_resource: Voelgoedevents.Ash.Changes.AuditChangeTest.FailingAuditLog,
            audit_domain: Voelgoedevents.Ash.Changes.AuditChangeTest.TestDomain
          ]}
      end
    end
  end

  @org_id "11111111-1111-1111-1111-111111111111"
  @actor_id "22222222-2222-2222-2222-222222222222"

  test "successful action writes an audit log" do
    actor = %{id: @actor_id, organization_id: @org_id}

    {:ok, resource} =
       Voelgoedevents.Ash.Changes.AuditChangeTest.TestResource
       |> Ash.Changeset.for_create(:create, %{name: "Test", organization_id: @org_id})
       |> Ash.create(actor: actor, domain: TestDomain)

    # Check that SuccessAuditLog has an entry
    logs = Ash.read!(SuccessAuditLog, domain: TestDomain)
    assert length(logs) == 1
    log = hd(logs)

    assert log.actor_id == @actor_id
    assert log.organization_id == @org_id
    assert log.resource_id == resource.id
    assert log.action == "create"
  end

  test "failed audit log creation rolls back transaction (raises)" do
    actor = %{id: @actor_id, organization_id: @org_id}

    assert_raise RuntimeError, ~r/Audit logging failed/, fn ->
       Voelgoedevents.Ash.Changes.AuditChangeTest.TestResource
       |> Ash.Changeset.for_create(:create_with_fail, %{name: "Test", organization_id: @org_id})
       |> Ash.create(actor: actor, domain: TestDomain)
    end
  end
end
