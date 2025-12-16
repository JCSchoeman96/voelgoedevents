defmodule Voelgoedevents.Ash.Policies.TenantPolicies do
  @moduledoc """
  Centralized authorization policies for multi-tenant RBAC.

  Enforces role-based access control across all VoelgoedEvents resources.

  NOTE: Organization filtering is handled by FilterByTenant preparation.
  This module ONLY enforces role-based decisions.
  """

  require Ash.Query

  # ============================================================================
  # RBAC Helper Functions (Used by all resource policies)
  # ============================================================================

  @doc "Check if user belongs to an organization (has membership)"
  def user_belongs_to_org?(actor, org_id) do
    case actor do
      nil ->
        false

      actor when is_map(actor) ->
        # actor.organization_id already filtered by FilterByTenant
        # Just check if it exists
        Map.get(actor, :organization_id) == org_id

      _ ->
        false
    end
  end

  @doc "Check if user has a specific role in an organization"
  def user_has_role?(actor, org_id, required_role) when is_atom(required_role) do
    case actor do
      nil ->
        false

      actor when is_map(actor) ->
        user_id = Map.get(actor, :id)

        # Load user's membership in this org (cached in ETS via MembershipCache)
        # Note: We query Membership directly here. In a hot path, this should ideally
        # hit the MembershipCache, but for policy authorization happening inside Ash,
        # we often rely on the actor already having context or a fast DB lookup.
        # Given MembershipCache exists, we could potentially leverage it if valid.
        # For now, we follow the standard Ash pattern of querying the join resource.
        Voelgoedevents.Ash.Resources.Accounts.Membership
        |> Ash.Query.filter(user_id: user_id)
        |> Ash.Query.filter(organization_id: org_id)
        |> Ash.Query.load(:role)
        |> Ash.read_one()
        |> case do
          {:ok, %{role: %{name: name}}} ->
            name == required_role

          _ ->
            false
        end

      _ ->
        false
    end
  end

  # ============================================================================
  # Policy Functions (Imported in resource policy blocks)
  # ============================================================================

  @doc """
  Authorize a READ action.

  Enforces authenticated, tenant-scoped reads. FilterByTenant handles data
  scoping; this macro ensures anonymous actors are denied and org alignment is
  enforced at the policy layer.
  """
  defmacro authorize_read do
    quote do
      policy action_type(:read) do
        forbid_if expr(is_nil(^actor(:user_id)))

        authorize_if expr(organization_id == ^actor(:organization_id))
      end
    end
  end

  @doc """
  Authorize a CREATE/UPDATE action by role.

  Requires: user belongs to org AND has required role.
  FilterByTenant ensures they can only create within their org.
  """
  defmacro authorize_write(required_roles) when is_list(required_roles) do
    quote do
      policy action_type([:create, :update]) do
        forbid_if expr(is_nil(^actor(:user_id)))

        authorize_if expr(
                       ^actor(:organization_id) == organization_id and
                         ^actor(:role) in unquote(required_roles)
                     )
      end
    end
  end

  @doc """
  Authorize a DESTROY action by role.

  Requires: user belongs to org AND has required role.
  """
  defmacro authorize_destroy(required_roles) when is_list(required_roles) do
    quote do
      policy action_type(:destroy) do
        forbid_if expr(is_nil(^actor(:user_id)))

        authorize_if expr(
                       ^actor(:organization_id) == organization_id and
                         ^actor(:role) in unquote(required_roles)
                     )
      end
    end
  end

  # ============================================================================
  # Preset Roles (Convenience functions)
  # ============================================================================

  def admin_only, do: [:owner, :admin]
  def staff_or_above, do: [:owner, :admin, :staff]
  def read_only, do: [:owner, :admin, :staff, :viewer]
  def scanner_only, do: [:scanner_only]
end
