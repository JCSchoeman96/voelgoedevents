defmodule Voelgoedevents.Ash.Preparations.FilterByTenant do
  @moduledoc """
  Preparation that filters queries by organization_id based on the actor.

  This ensures tenant isolation by automatically scoping all reads to the
  actor's organization. Platform admins can bypass this with :skip_tenant_rule.
  """

  use Ash.Resource.Preparation
  require Ash.Query

  @impl true
  def prepare(query, _opts, context) do
    # In Ash 3.x, context is a struct with .actor, .tenant, etc.
    actor = context.actor
    source_context = context.source_context || %{}
    skip? = Map.get(source_context, :skip_tenant_rule, false)

    org_id_from_actor =
      case actor do
        %{organization_id: org_id} when not is_nil(org_id) -> org_id
        _ -> nil
      end

    org_id_from_context = Map.get(source_context, :organization_id)

    cond do
      # 0. Escape hatch: only platform admins may skip tenant rule
      skip? and match?(%{is_platform_admin: true}, actor) ->
        query

      skip? ->
        raise "FilterByTenant: :skip_tenant_rule may only be used with platform-admin actors"

      # 1. Tenant user / admin – prefer organization_id from actor
      not is_nil(org_id_from_actor) ->
        Ash.Query.filter(query, organization_id == ^org_id_from_actor)

      # 2. Fallback: context carries active tenant
      not is_nil(org_id_from_context) ->
        Ash.Query.filter(query, organization_id == ^org_id_from_context)

      # 3. No actor provided (bypass for admin/test reads with authorize?: false)
      is_nil(actor) ->
        query

      # 4. Fail closed – actor provided but no org context
      true ->
        raise "FilterByTenant requires actor with organization_id, context with organization_id, or platform_admin privileges"
    end
  end
end
