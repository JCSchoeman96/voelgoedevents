defmodule Voelgoedevents.Ash.Support.ActorUtils do
  @moduledoc """
  Canonical actor normalization and validation utilities for Ash 3.x.

  This module enforces the global identity model & multi-tenancy invariants
  defined in `/docs/domain/rbac_and_platform_access.md`.

  Key Guarantees:

  • Correct actor extraction from Ash context maps (%{actor: ...})
  • Strict type validation (no guessing)
  • Canonical shape: user/device/api_key/system
  • RBAC rules applied at the actor-shape level
  • Multi-tenancy invariants:
      – All actors must have organization_id
        (except Super Admin in platform dashboards)
      – System/device/api_key MUST always include organization_id
  • Role validation restricted to RBAC enumerations
  • Audit-safe metadata generation
  """

  @type actor_type :: :user | :device | :api_key | :system | nil

  @type role_type ::
          :owner
          | :admin
          | :staff
          | :viewer
          | :scanner_only
          | nil

  @type actor :: %{
          type: actor_type,
          user_id: String.t() | nil,
          device_id: String.t() | nil,
          api_key_id: String.t() | nil,
          organization_id: String.t() | nil,
          role: role_type,
          is_platform_admin: boolean(),
          is_platform_staff: boolean(),
          scopes: list(String.t()),
          device_token: String.t() | nil,
          gate_id: String.t() | nil
        }

  # ------------------------------------------------------------
  # Public Normalizer
  # ------------------------------------------------------------

  @spec normalize(any()) :: actor | nil
  def normalize(nil), do: nil

  # Extract from Ash 3.x context: %{actor: %{...}}
  def normalize(%{actor: actor}), do: normalize(actor)

  # Structs → Sanitized maps
  def normalize(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> sanitize()
  end

  # Maps → Sanitized
  def normalize(map) when is_map(map), do: sanitize(map)

  def normalize(_), do: nil

  # ------------------------------------------------------------
  # Sanitization & Shape Enforcement
  # ------------------------------------------------------------

  defp sanitize(map) do
    map = Map.drop(map, [:__struct__])
    type = determine_type(map)

    if is_nil(type) do
      nil
    else
      actor = %{
        type: type,
        user_id: Map.get(map, :user_id) || Map.get(map, :id),
        device_id: Map.get(map, :device_id),
        api_key_id: Map.get(map, :api_key_id),
        organization_id: Map.get(map, :organization_id),
        role: map |> Map.get(:role) |> normalize_role(),
        is_platform_admin: Map.get(map, :is_platform_admin, false),
        is_platform_staff: Map.get(map, :is_platform_staff, false),
        scopes: Map.get(map, :scopes, []),
        device_token: Map.get(map, :device_token),
        gate_id: Map.get(map, :gate_id)
      }

      validate_actor_shape(actor)
    end
  end

  # Only allow the roles from RBAC spec
  defp normalize_role(nil), do: nil
  defp normalize_role(role) when role in [:owner, :admin, :staff, :viewer, :scanner_only], do: role
  defp normalize_role(_), do: nil

  # ------------------------------------------------------------
  # Strict Actor Type Determination
  # ------------------------------------------------------------

  @spec determine_type(map()) :: actor_type
  def determine_type(%{type: t}) when t in [:user, :device, :api_key, :system], do: t

  # Device/API key explicit identifiers
  def determine_type(%{device_id: id}) when is_binary(id), do: :device
  def determine_type(%{api_key_id: id}) when is_binary(id), do: :api_key

  # User context
  def determine_type(%{user_id: id}) when is_binary(id), do: :user

  # Backwards-safe rule:
  # User struct from DB: %{id: ..., email: ...}
  def determine_type(%{email: _, id: id}) when is_binary(id), do: :user

  # system actor
  def determine_type(%{actor_id: "system"}), do: :system

  def determine_type(_), do: nil

  # ------------------------------------------------------------
  # Actor Shape Validation (RBAC + Multi-Tenancy)
  # ------------------------------------------------------------

  # USER
  defp validate_actor_shape(%{type: :user} = actor) do
    cond do
      # Super Admin: allowed both scoped and unscoped, even with nil role.
      # Authorization for these cases is handled explicitly in policies via
      # actor(:is_platform_admin) checks.
      actor.is_platform_admin ->
        actor

      # Regular users MUST have an organization_id
      is_nil(actor.organization_id) ->
        nil

      # Regular users MUST have a role inside a tenant
      is_nil(actor.role) ->
        nil

      true ->
        actor
    end
  end

  # SYSTEM (must ALWAYS have org_id, cannot be unscoped)
  defp validate_actor_shape(%{type: :system} = actor) do
    if is_binary(actor.organization_id) do
      actor
    else
      nil
    end
  end

  # DEVICE (must always be org-scoped)
  defp validate_actor_shape(%{type: :device} = actor) do
    if is_binary(actor.organization_id) do
      actor
    else
      nil
    end
  end

  # API KEY (must always be org-scoped)
  defp validate_actor_shape(%{type: :api_key} = actor) do
    if is_binary(actor.organization_id) do
      actor
    else
      nil
    end
  end

  defp validate_actor_shape(_), do: nil

  # ------------------------------------------------------------
  # Organization Enforcement
  # ------------------------------------------------------------

  @doc """
  Strict organization_id extraction.

  Returns:
    {:ok, org_id}
    :platform_admin_unscoped
    :error
  """
  def get_organization_id(actor) do
    case normalize(actor) do
      nil -> :error

      # These must always have org_id
      %{type: :system, organization_id: nil} -> :error
      %{type: t, organization_id: nil} when t in [:device, :api_key] -> :error

      # Super admin special case
      %{type: :user, is_platform_admin: true, organization_id: nil} ->
        :platform_admin_unscoped

      # Regular users MUST have org id
      %{type: :user, organization_id: nil} ->
        :error

      # Normal case
      %{organization_id: org_id} ->
        {:ok, org_id}
    end
  end

  # ------------------------------------------------------------
  # Privilege Helpers
  # ------------------------------------------------------------

  def is_platform_admin?(actor), do: match?(%{is_platform_admin: true}, normalize(actor))
  def is_platform_staff?(actor), do: match?(%{is_platform_staff: true}, normalize(actor))

  # ------------------------------------------------------------
  # Audit Metadata (canonical)
  # ------------------------------------------------------------

  @doc """
  Safe metadata for AuditLog resource.

  Returns struct with:
    actor_id, actor_type, actor_role,
    actor_is_platform_admin, actor_is_platform_staff,
    organization_id
  """
  def to_audit_metadata(actor) do
    case normalize(actor) do
      nil ->
        %{
          actor_id: nil,
          actor_type: nil,
          actor_role: nil,
          actor_is_platform_admin: false,
          actor_is_platform_staff: false,
          organization_id: nil
        }

      norm ->
        actor_id =
          case norm.type do
            :user -> norm.user_id
            :device -> norm.device_id
            :api_key -> norm.api_key_id
            :system -> "system"
            _ -> nil
          end

        %{
          actor_id: actor_id,
          actor_type: norm.type,
          actor_role: norm.role,
          actor_is_platform_admin: norm.is_platform_admin,
          actor_is_platform_staff: norm.is_platform_staff,
          organization_id: norm.organization_id
        }
    end
  end
end
