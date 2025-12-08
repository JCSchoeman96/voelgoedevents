defmodule Voelgoedevents.Ash.Preparations.FilterByTenant do
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, context) do
    actor = context[:actor]
    skip? = context[:skip_tenant_rule] || false

    org_id_from_actor =
      case actor do
        %{organization_id: org_id} when not is_nil(org_id) -> org_id
        _ -> nil
      end

    org_id_from_context = context[:organization_id]

    cond do
      # 0. Escape hatch: only platform admins may skip tenant rule
      skip? and match?(%{is_platform_admin: true}, actor) ->
        query

      skip? ->
        raise "FilterByTenant: :skip_tenant_rule may only be used with platform-admin actors"

      # 1. Tenant user / admin – prefer organization_id from actor
      not is_nil(org_id_from_actor) ->
        Ash.Query.filter(query, organization_id: ^org_id_from_actor)

      # 2. Fallback: context carries active tenant
      not is_nil(org_id_from_context) ->
        Ash.Query.filter(query, organization_id: ^org_id_from_context)

      # 3. Fail closed – neither actor nor context carries org
      true ->
        raise "FilterByTenant requires actor or context with organization_id, or platform_admin privileges"
    end
  end
end
