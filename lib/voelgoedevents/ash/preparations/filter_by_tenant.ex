defmodule Voelgoedevents.Ash.Preparations.FilterByTenant do
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, context) do
    actor = context[:actor]

    org_id_from_actor =
      case actor do
        %{organization_id: org_id} when not is_nil(org_id) -> org_id
        _ -> nil
      end

    org_id_from_context = context[:organization_id]

    cond do
      # 1. Platform admin / super admin – no tenant restriction
      match?(%{is_platform_admin: true}, actor) ->
        query

      # 2. Tenant user – prefer organization_id from actor
      not is_nil(org_id_from_actor) ->
        Ash.Query.filter(query, organization_id: ^org_id_from_actor)

      # 3. Fallback – use organization_id from context (e.g. LoadTenant / CurrentUserPlug)
      not is_nil(org_id_from_context) ->
        Ash.Query.filter(query, organization_id: ^org_id_from_context)

      # 4. Fail closed – neither actor nor context carries org
      true ->
        raise "FilterByTenant requires actor or context with organization_id, or platform_admin privileges"
    end
  end
end
