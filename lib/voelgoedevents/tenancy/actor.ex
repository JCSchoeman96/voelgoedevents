defmodule Voelgoedevents.Tenancy.Actor do
  @moduledoc """
  Helpers for constructing actors with tenant context for Ash calls
  (web, jobs, and system flows).
  """

  def user_actor(%{id: _id} = user, org_id) when not is_nil(org_id) do
    Map.merge(user, %{organization_id: org_id})
  end

  def system_actor(org_id, opts \\ []) when not is_nil(org_id) do
    %{
      id: :system,
      organization_id: org_id,
      role: opts[:role] || :system_worker,
      is_platform_admin: opts[:is_platform_admin] || false
    }
  end
end
