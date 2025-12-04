defmodule Voelgoedevents.Ash.Policies.PlatformPolicy do
  @moduledoc """
  Platform admin short-circuit policy helper.

  Inserts a `bypass?: true` policy that authorizes actors flagged with
  `:is_platform_admin` (or the `:is_platform_admin?` accessor) before tenant or
  RBAC checks run. This aligns with the security architecture: platform admins
  can act as Root for authorization decisions while auditing and rate limiting
  still execute via their own extensions/changes.

  Place this helper at the top of a resource's `policies` block—after any
  auditing or rate-limiting policies if they are expressed as policies, but
  before tenant/RBAC enforcement—so platform operators can recover or
  override without weakening safety controls.
  """

  @doc """
  Adds a platform-admin bypass policy for all action types.

  This only short-circuits authorization; auditing, rate-limiting, and other
  non-authorization hooks must still run in their own layers.
  """
  defmacro platform_admin_root_access do
    quote do
      policy action_type([:read, :create, :update, :destroy, :action]) do
        bypass? true
        description "Platform admin root access (authorization only; audit/rate limits still apply)"
        authorize_if expr(actor(:is_platform_admin) == true or actor(:is_platform_admin?) == true)
      end
    end
  end
end
