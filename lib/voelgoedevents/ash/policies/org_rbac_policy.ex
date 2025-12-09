defmodule Voelgoedevents.Ash.Policies.OrgRbacPolicy do
  @moduledoc """
  Organization-level RBAC helpers for Ash policies.

  Provides a single source of truth for org roles (owner → admin → staff →
  viewer → scanner_only) and exposes macros like `can?(:admin)` to express
  role gates consistently. The checks are pure: they rely on the actor,
  resource context, or `conn.assigns` and never hit the database. Platform
  admins automatically satisfy every role requirement via the platform-admin
  bypass convention.
  """

  @role_hierarchy [:owner, :admin, :staff, :viewer, :scanner_only]
  @role_rank Map.new(Enum.with_index(@role_hierarchy))

  @doc """
  Authorize when the actor has at least the required organization role.

  Usage inside a `policies` block:

      require Voelgoedevents.Ash.Policies.OrgRbacPolicy

      policy action(:update) do
        Voelgoedevents.Ash.Policies.OrgRbacPolicy.can?(:admin)
      end
  """
  defmacro can?(role) when is_atom(role) do
    unless role in @role_hierarchy do
      raise ArgumentError,
            "Unknown org role #{inspect(role)}. Allowed roles: #{inspect(@role_hierarchy)}"
    end

    quote do
      authorize_if unquote(__MODULE__).OrgRoleCheck, at_least: unquote(role)
    end
  end

  @doc """
  Returns true when the actor meets the role requirement or is a platform admin.
  """
  @spec role_at_least?(map() | nil, map(), atom()) :: boolean()
  def role_at_least?(actor, context, required_role) when is_atom(required_role) do
    unless required_role in @role_hierarchy do
      raise ArgumentError,
            "Unknown org role #{inspect(required_role)}. Allowed roles: #{inspect(@role_hierarchy)}"
    end

    platform_admin?(actor) or role_allowed?(current_role(actor, context), required_role)
  end

  defp platform_admin?(actor) do
    Map.get(actor || %{}, :is_platform_admin) == true or
      Map.get(actor || %{}, :is_platform_admin?) == true
  end

  defp current_role(actor, context) do
    actor_role(actor) || context_role(context)
  end

  defp actor_role(%{organization_role: role}) when is_atom(role), do: role
  defp actor_role(%{membership_role: role}) when is_atom(role), do: role
  defp actor_role(%{role: role}) when is_atom(role), do: role
  defp actor_role(_), do: nil

  defp context_role(%{context: inner}), do: context_role(inner)
  defp context_role(%{conn: %Plug.Conn{assigns: assigns}}), do: assigns_role(assigns)
  defp context_role(%{conn_assigns: assigns}) when is_map(assigns), do: assigns_role(assigns)
  defp context_role(%Plug.Conn{assigns: assigns}), do: assigns_role(assigns)
  defp context_role(%{assigns: assigns}) when is_map(assigns), do: assigns_role(assigns)
  defp context_role(_), do: nil

  defp assigns_role(assigns) do
    [:organization_role, :membership_role, :current_membership_role]
    |> Enum.find_value(fn key ->
      case Map.get(assigns, key) do
        role when is_atom(role) -> role
        _ -> nil
      end
    end)
  end

  defp role_allowed?(role, required) when role == required, do: true

  defp role_allowed?(role, required) when is_atom(role) do
    case {Map.get(@role_rank, role), Map.get(@role_rank, required)} do
      {role_rank, required_rank} when is_integer(role_rank) and is_integer(required_rank) ->
        role_rank <= required_rank

      _ ->
        false
    end
  end

  defp role_allowed?(_role, _required), do: false

  defmodule OrgRoleCheck do
    @moduledoc false

    use Ash.Policy.SimpleCheck

    @impl true
    def describe(opts) do
      required = opts[:at_least] || :unknown

      "requires org role #{required} or platform admin bypass"
    end

    @impl true
    def match?(actor, context, opts) do
      Voelgoedevents.Ash.Policies.OrgRbacPolicy.role_at_least?(actor, context, opts[:at_least])
    end
  end
end
