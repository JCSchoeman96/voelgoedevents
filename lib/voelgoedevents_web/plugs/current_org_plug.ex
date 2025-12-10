defmodule VoelgoedeventsWeb.Plugs.CurrentOrgPlug do
  @moduledoc """
  Determines organization context and user role based on session selection.
  Runs AFTER CurrentUserPlug.

  ## Responsibilities (Org + Role Determination)

  This plug handles organization and role resolution:
  - Determine selected org (from session, falling back to user's default)
  - Verify user has active membership in selected org (unless platform admin)
  - Extract user's role in that org
  - Assign `current_organization_id`, `current_role`
  - Pass through platform admin/staff flags

  ## Platform Admin Override

  Platform admins can access ANY organization without membership.
  Their role inside the org is `nil` (they operate with platform privileges).
  See: /docs/domain/rbac_and_platform_access.md

  ## What This Plug Does NOT Do

  - Does NOT build the Ash actor (that's SetAshActorPlug's job)
  - Does NOT call ActorUtils
  - Does NOT set Ash context (that's SetAshActorPlug's job)

  ## Pipeline Position

  1. `CurrentUserPlug` (identity + memberships loaded)
  2. `CurrentOrgPlug` ← YOU ARE HERE (org + role determination)
  3. `SetAshActorPlug` (actor construction via ActorUtils)

  ## Assigns Set

  - `current_organization_id` - The validated organization ID
  - `current_role` - User's role in this organization (:owner, :admin, :staff, :viewer, :scanner_only, or nil for platform admins)
  - `current_platform_admin?` - Pass-through of platform admin flag
  - `current_platform_staff?` - Pass-through of platform staff flag
  """

  import Plug.Conn
  require Ash.Query

  alias Voelgoedevents.Ash.Resources.Accounts.Membership

  def init(opts), do: opts

  def call(conn, _opts) do
    user = conn.assigns[:current_user]
    is_platform_admin = conn.assigns[:is_platform_admin] || false
    is_platform_staff = conn.assigns[:is_platform_staff] || false

    # Prefer session-selected org, fallback to user's default (from CurrentUserPlug)
    selected_org_id =
      get_session(conn, :selected_organization_id) ||
        conn.assigns[:current_organization_id]

    # Resolve org and role based on membership (or platform admin override)
    {org_id, role} = resolve_org_and_role(user, selected_org_id, is_platform_admin)

    conn
    |> assign(:current_organization_id, org_id)
    |> assign(:organization_id, org_id)
    |> assign(:current_role, role)
    |> assign(:current_platform_admin?, is_platform_admin)
    |> assign(:current_platform_staff?, is_platform_staff)
  end

  # No user = no org context
  defp resolve_org_and_role(nil, _org_id, _is_platform_admin), do: {nil, nil}

  # No org selected
  defp resolve_org_and_role(_user, nil, _is_platform_admin), do: {nil, nil}

  # Invalid org_id format
  defp resolve_org_and_role(_user, org_id, _is_platform_admin) when not is_binary(org_id),
    do: {nil, nil}

  # Platform admin may access any tenant without membership
  # Their role inside org = nil (they operate with platform privileges)
  defp resolve_org_and_role(_user, org_id, true = _is_platform_admin) when is_binary(org_id) do
    {org_id, nil}
  end

  # Regular users: verify membership and extract role
  defp resolve_org_and_role(user, org_id, false = _is_platform_admin) do
    case fetch_membership_role(user.id, org_id) do
      {:ok, role} -> {org_id, role}
      :error -> {nil, nil}
    end
  end

  defp fetch_membership_role(user_id, org_id) do
    query =
      Membership
      |> Ash.Query.filter(user_id == ^user_id and organization_id == ^org_id and status == :active)
      |> Ash.Query.load(:role)

    case Ash.read_one(query, actor: nil) do
      {:ok, %{role: %{name: role_name}}} when not is_nil(role_name) ->
        {:ok, role_name}

      {:ok, %{role: role_atom}} when is_atom(role_atom) and not is_nil(role_atom) ->
        {:ok, role_atom}

      _ ->
        :error
    end
  end
end
