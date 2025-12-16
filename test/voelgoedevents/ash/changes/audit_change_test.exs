defmodule Voelgoedevents.Ash.Changes.AuditChangeTest do
  use ExUnit.Case, async: true

  @org_id "11111111-1111-1111-1111-111111111111"
  @actor_id "22222222-2222-2222-2222-222222222222"

  test "successful action writes an audit log" do
    actor = actor()

    {:ok, resource} =
      Voelgoedevents.Ash.Changes.AuditChangeTest.TestResource
      |> Ash.Changeset.for_create(:create, %{name: "Test", organization_id: @org_id})
      |> Ash.create(actor: actor, domain: Voelgoedevents.Ash.Changes.AuditChangeTest.TestDomain)


    logs =
      Ash.read!(
        Voelgoedevents.Ash.Changes.AuditChangeTest.SuccessAuditLog,
        domain: Voelgoedevents.Ash.Changes.AuditChangeTest.TestDomain
      )

    assert length(logs) == 1
    log = hd(logs)

    assert log.actor_id == @actor_id
    assert log.organization_id == @org_id
    assert log.resource_id == resource.id
    assert log.action == "create"
  end

  test "failed audit log creation rolls back transaction (raises)" do
    actor = actor()

    error =
      assert_raise Ash.Error.Unknown, fn ->
        Voelgoedevents.Ash.Changes.AuditChangeTest.TestResource
        |> Ash.Changeset.for_create(:create_with_fail, %{name: "Test", organization_id: @org_id})
        |> Ash.create(actor: actor, domain: Voelgoedevents.Ash.Changes.AuditChangeTest.TestDomain)
      end

    assert Exception.message(error) =~ "Audit logging failed"
  end

  defp actor do
    %{
      user_id: @actor_id,
      organization_id: @org_id,
      role: :viewer,
      is_platform_admin: false,
      is_platform_staff: false,
      type: :user
    }
  end
end
