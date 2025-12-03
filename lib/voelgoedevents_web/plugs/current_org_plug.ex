defmodule VoelgoedeventsWeb.Plugs.CurrentOrgPlug do
  @moduledoc """
  Ensures the current user is allowed to access the scoped organization.

  Platform admins may bypass membership checks after tenant resolution. Other
  users must have an active membership for the current organization, otherwise a
  403 response is returned.
  """

  import Plug.Conn

  alias Voelgoedevents.Ash.Resources.Accounts.User
  alias Voelgoedevents.Auth.RbacCache

  def init(opts), do: opts

  def call(conn, _opts) do
    with %User{} = user <- conn.assigns[:current_user],
         %{id: organization_id} <- conn.assigns[:current_organization],
         true <- authorized_for_org?(user, organization_id) do
      conn
      |> assign(:organization_id, organization_id)
      |> Ash.PlugHelpers.set_actor(Map.put(user, :organization_id, organization_id))
    else
      nil ->
        conn
        |> send_resp(:unauthorized, "Unauthorized")
        |> halt()

      false ->
        conn
        |> send_resp(:forbidden, "Forbidden")
        |> halt()
    end
  end

  defp authorized_for_org?(%User{} = user, organization_id) do
    platform_admin?(user) or active_member?(user, organization_id)
  end

  defp platform_admin?(%User{} = user), do: Map.get(user, :is_platform_admin?, false)

  defp active_member?(%User{id: user_id, memberships: memberships}, organization_id) when is_list(memberships) do
    memberships
    |> Enum.any?(fn membership ->
      membership.organization_id == organization_id and membership.status == :active
    end)
    |> case do
      true -> true
      false -> check_membership_cache(user_id, organization_id)
    end
  end

  defp active_member?(%User{id: user_id}, organization_id), do: check_membership_cache(user_id, organization_id)

  defp check_membership_cache(user_id, organization_id) do
    case RbacCache.fetch_role(user_id, organization_id, actor: %{id: user_id, organization_id: organization_id}) do
      {:ok, _role} -> true
      {:error, _reason} -> false
    end
  end
end
