defmodule VoelgoedeventsWeb.Plugs.SetAshActorPlug do
  @moduledoc """
  Final plug in the authentication chain that constructs a fully-hydrated Ash actor.

  ## Hydration Pipeline

  1. `CurrentUserPlug` - Loads authenticated user, sets initial context
  2. `CurrentOrgPlug` - Determines active organization
  3. `SetAshActorPlug` - **Hydrates actor with organization_id and role** ← YOU ARE HERE

  ## Actor Structure

  The actor passed to Ash MUST contain:
  - `:id` - User ID
  - `:organization_id` - Active organization ID
  - `:role` - User's role in the active organization (`:owner`, `:admin`, `:staff`, `:viewer`, `:scanner`)
  - `:is_platform_admin` - Boolean indicating platform admin status

  This ensures all Ash policies have access to the complete authorization context.

  ## Usage

  Add to router pipeline AFTER CurrentUserPlug and CurrentOrgPlug:

  ```elixir
  pipeline :browser do
    plug :fetch_session
    plug VoelgoedeventsWeb.Plugs.CurrentUserPlug
    plug VoelgoedeventsWeb.Plugs.CurrentOrgPlug
    plug VoelgoedeventsWeb.Plugs.SetAshActorPlug  # ← Hydrates actor
  end
  ```

  ## Implementation Notes

  - If no user is authenticated, actor remains `nil`
  - If user has no organization, actor includes user ID only
  - Role is fetched from Membership for the current organization
  - Platform admins get `is_platform_admin: true` flag
  """

  import Plug.Conn
  require Ash.Query

  alias Voelgoedevents.Ash.Domains.AccountsDomain
  alias Voelgoedevents.Ash.Resources.Accounts.Membership

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    org_id = conn.assigns[:current_organization_id]

    actor = build_actor(user, org_id)

    conn
    |> Ash.PlugHelpers.set_actor(actor)
  end

  defp build_actor(nil, _org_id), do: nil

  defp build_actor(user, nil) do
    # User authenticated but no organization selected
    %{
      id: user.id,
      organization_id: nil,
      role: nil,
      is_platform_admin: is_platform_admin?(user)
    }
  end

  defp build_actor(user, org_id) do
    # Full hydration: fetch role for this org
    role = fetch_user_role(user.id, org_id)

    %{
      id: user.id,
      organization_id: org_id,
      role: role,
      is_platform_admin: is_platform_admin?(user)
    }
  end

  defp fetch_user_role(user_id, org_id) do
    # Fetch user's role from Membership resource for the current organization
    query =
      Membership
      |> Ash.Query.filter(user_id == ^user_id and organization_id == ^org_id and status == :active)
      |> Ash.Query.select([:role])

    case AccountsDomain.read_one(query, actor: nil) do
      {:ok, %{role: role}} -> role
      _ -> nil  # No active membership found
    end
  end

  defp is_platform_admin?(%{is_platform_admin: true}), do: true
  defp is_platform_admin?(_), do: false
end
