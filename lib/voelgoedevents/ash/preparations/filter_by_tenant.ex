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
    actor = Map.get(context, :actor)
    source_context = Map.get(context, :source_context, %{})
    skip? =
      Map.get(context, :skip_tenant_rule, false) ||
        Map.get(source_context, :skip_tenant_rule, false)
    platform_admin? = is_map(actor) and Map.get(actor, :is_platform_admin) == true

    cond do
      skip? and platform_admin? ->
        query

      skip? ->
        raise "skip_tenant_rule may only be used with platform-admin actors"

      true ->
        org_id =
          Map.get(actor || %{}, :organization_id) ||
            Map.get(context, :organization_id) ||
            Map.get(source_context, :organization_id) ||
            raise("FilterByTenant requires actor or context with organization_id")

        Ash.Query.filter(query, organization_id == ^org_id)
    end
  end
end
