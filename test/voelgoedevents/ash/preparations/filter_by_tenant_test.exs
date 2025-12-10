defmodule Voelgoedevents.Ash.Preparations.FilterByTenantTest do
  use ExUnit.Case, async: true
  alias Voelgoedevents.Ash.Preparations.FilterByTenant
  require Ash.Query

  # Minimal domain for testing
  defmodule TestDomain do
    use Ash.Domain,
      resources: [
        Voelgoedevents.Ash.Preparations.FilterByTenantTest.TenantResource
      ]
  end

  # Minimal resource for testing
  defmodule TenantResource do
    use Ash.Resource,
      domain: Voelgoedevents.Ash.Preparations.FilterByTenantTest.TestDomain,
      data_layer: Ash.DataLayer.Simple

    attributes do
      uuid_primary_key :id
      attribute :organization_id, :uuid, allow_nil?: false
    end
  end

  test "normal actor with organization_id filters query by that org" do
    org_id = "11111111-1111-1111-1111-111111111111"
    actor = actor(%{id: "22222222-2222-2222-2222-222222222222", organization_id: org_id})
    context = %{actor: actor}

    query = Ash.Query.new(TenantResource)

    prepared = FilterByTenant.prepare(query, [], context)

    assert %Ash.Filter{expression: expression} = prepared.filter

    assert %Ash.Query.BooleanExpression{
             op: :eq,
             left: %Ash.Query.Ref{attribute: %Ash.Resource.Attribute{name: :organization_id}},
             right: ^org_id
           } = expression
  end

  test "actor without org but context has organization_id uses context org" do
    org_id = "33333333-3333-3333-3333-333333333333"
    actor = actor(%{id: "44444444-4444-4444-4444-444444444444"})
    context = %{actor: actor, organization_id: org_id}

    query = Ash.Query.new(TenantResource)
    prepared = FilterByTenant.prepare(query, [], context)

    assert %Ash.Filter{expression: expression} = prepared.filter

    assert %Ash.Query.BooleanExpression{
             op: :eq,
             left: %Ash.Query.Ref{attribute: %Ash.Resource.Attribute{name: :organization_id}},
             right: ^org_id
           } = expression
  end

  test "no actor but context has organization_id uses context org" do
    org_id = "77777777-7777-7777-7777-777777777777"
    context = %{actor: nil, organization_id: org_id}

    query = Ash.Query.new(TenantResource)
    prepared = FilterByTenant.prepare(query, [], context)

    assert %Ash.Filter{expression: expression} = prepared.filter

    assert %Ash.Query.BooleanExpression{
             op: :eq,
             left: %Ash.Query.Ref{attribute: %Ash.Resource.Attribute{name: :organization_id}},
             right: ^org_id
           } = expression
  end

  test "platform admin with skip_tenant_rule bypasses tenant filter" do
    actor = actor(%{id: "55555555-5555-5555-5555-555555555555", is_platform_admin: true})

    context = %{actor: actor, skip_tenant_rule: true}

    query = Ash.Query.new(TenantResource)
    prepared = FilterByTenant.prepare(query, [], context)

    # Filter should be nil (empty) – global read
    assert is_nil(prepared.filter)
  end

  test "platform admin without skip_tenant_rule is still tenant-scoped" do
    org_id = "99999999-9999-9999-9999-999999999999"

    actor =
      actor(%{
        id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
        is_platform_admin: true,
        organization_id: org_id
      })

    context = %{actor: actor}

    query = Ash.Query.new(TenantResource)
    prepared = FilterByTenant.prepare(query, [], context)

    assert %Ash.Filter{expression: expression} = prepared.filter

    assert %Ash.Query.BooleanExpression{
             op: :eq,
             left: %Ash.Query.Ref{attribute: %Ash.Resource.Attribute{name: :organization_id}},
             right: ^org_id
           } = expression
  end

  test "non-admin with skip_tenant_rule raises error" do
    actor = actor(%{id: "88888888-8888-8888-8888-888888888888"})
    context = %{actor: actor, skip_tenant_rule: true}

    query = Ash.Query.new(TenantResource)

    assert_raise RuntimeError,
                 ~r/skip_tenant_rule may only be used with platform-admin actors/,
                 fn ->
                   FilterByTenant.prepare(query, [], context)
                 end
  end

  test "missing org and non-admin raises error" do
    actor = actor(%{id: "66666666-6666-6666-6666-666666666666"})
    context = %{actor: actor}

    query = Ash.Query.new(TenantResource)

    assert_raise RuntimeError,
                 ~r/FilterByTenant requires actor or context with organization_id/,
                 fn ->
                   FilterByTenant.prepare(query, [], context)
                 end
  end

  defp actor(attrs) do
    Map.merge(
      %{
        id: Ecto.UUID.generate(),
        organization_id: nil,
        role: nil,
        is_platform_admin: false,
        is_platform_staff: false,
        type: :user
      },
      attrs
    )
  end
end
