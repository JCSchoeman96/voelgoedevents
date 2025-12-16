defmodule Voelgoedevents.Ash.Support.ActorUtils do
  @moduledoc """
  Canonical actor normalization and validation utilities for Ash 3.x.

  Normalizes any incoming actor shape to the canonical 6-field actor map:

      %{
        user_id: uuid | "system",
        organization_id: uuid | nil,
        role: :owner | :admin | :staff | :viewer | :scanner_only | :system,
        is_platform_admin: boolean(),
        is_platform_staff: boolean(),
        type: :user | :system | :device | :api_key
      }

  Any missing or invalid field returns `{:error, :invalid_actor}`; use
  `normalize!/1` when you want a hard failure.
  """

  @type actor_type :: :user | :device | :api_key | :system
  @type role_type :: :owner | :admin | :staff | :viewer | :scanner_only | :system

  @type actor :: %{
          user_id: String.t(),
          organization_id: String.t() | nil,
          role: role_type,
          is_platform_admin: boolean(),
          is_platform_staff: boolean(),
          type: actor_type
        }

  @roles [:owner, :admin, :staff, :viewer, :scanner_only, :system]
  @types [:user, :system, :device, :api_key]

  # ------------------------------------------------------------
  # Public Normalizer
  # ------------------------------------------------------------

  @spec normalize(any()) :: {:ok, actor} | {:error, :invalid_actor}
  def normalize(input) do
    input
    |> do_normalize()
    |> validate_actor()
  end

  @spec normalize!(any()) :: actor
  def normalize!(input) do
    case normalize(input) do
      {:ok, actor} ->
        actor

      {:error, :invalid_actor} ->
        raise ArgumentError,
              "Invalid actor shape. Expected %{user_id, organization_id, role, is_platform_admin, is_platform_staff, type}"
    end
  end

  # ------------------------------------------------------------
  # Sanitization & Shape Enforcement
  # ------------------------------------------------------------

  defp do_normalize(%{actor: actor}), do: do_normalize(actor)
  defp do_normalize(%{__struct__: _} = struct), do: struct |> Map.from_struct() |> do_normalize()
  defp do_normalize(map) when is_map(map), do: sanitize_map(map)
  defp do_normalize(_), do: :invalid

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
      {:ok, %{is_platform_admin: true, organization_id: nil}} -> :platform_admin_unscoped
      {:ok, %{organization_id: org_id}} -> {:ok, org_id}
      {:error, :invalid_actor} -> :error
    end
  end

  # ------------------------------------------------------------
  # Privilege Helpers
  # ------------------------------------------------------------

  def is_platform_admin?(actor) do
    match?({:ok, %{is_platform_admin: true}}, normalize(actor))
  end

  def is_platform_staff?(actor) do
    match?({:ok, %{is_platform_staff: true}}, normalize(actor))
  end

  def primary_role(actor) do
    case normalize(actor) do
      {:ok, %{role: role}} -> role
      {:error, :invalid_actor} -> nil
    end
  end

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
      {:ok, norm} ->
        %{
          actor_id: norm.user_id,
          actor_type: norm.type,
          actor_role: norm.role,
          actor_is_platform_admin: norm.is_platform_admin,
          actor_is_platform_staff: norm.is_platform_staff,
          organization_id: norm.organization_id
        }

      {:error, :invalid_actor} ->
        %{
          actor_id: nil,
          actor_type: nil,
          actor_role: nil,
          actor_is_platform_admin: false,
          actor_is_platform_staff: false,
          organization_id: nil
        }
    end
  end

  defp sanitize_map(map) do
    %{
      user_id: Map.get(map, :user_id) || Map.get(map, :id) || Map.get(map, :actor_id),
      organization_id: Map.get(map, :organization_id) || Map.get(map, :org_id),
      role: normalize_role(map),
      is_platform_admin:
        Map.get(map, :is_platform_admin, Map.get(map, :is_platform_admin?, false)),
      is_platform_staff:
        Map.get(map, :is_platform_staff, Map.get(map, :is_platform_staff?, false)),
      type: normalize_type(map)
    }
  end

  defp normalize_role(map) do
    cond do
      is_atom(Map.get(map, :role)) -> Map.get(map, :role)
      is_atom(Map.get(map, :organization_role)) -> Map.get(map, :organization_role)
      is_atom(Map.get(map, :membership_role)) -> Map.get(map, :membership_role)
      true -> nil
    end
  end

  defp normalize_type(map) do
    cond do
      Map.get(map, :type) in @types -> Map.get(map, :type)
      Map.get(map, :device_id) -> :device
      Map.get(map, :api_key_id) -> :api_key
      Map.get(map, :actor_id) == "system" -> :system
      true -> :user
    end
  end

  defp validate_actor(:invalid), do: {:error, :invalid_actor}

  defp validate_actor(%{
         user_id: user_id,
         organization_id: org_id,
         role: role,
         is_platform_admin: is_platform_admin,
         is_platform_staff: is_platform_staff,
         type: type
       }) do
    cond do
      not is_binary(user_id) ->
        {:error, :invalid_actor}

      role not in @roles ->
        {:error, :invalid_actor}

      type not in @types ->
        {:error, :invalid_actor}

      is_nil(org_id) and not is_platform_admin ->
        {:error, :invalid_actor}

      not is_boolean(is_platform_admin) or not is_boolean(is_platform_staff) ->
        {:error, :invalid_actor}

      true ->
        {:ok,
         %{
           user_id: user_id,
           organization_id: org_id,
           role: role,
           is_platform_admin: is_platform_admin,
           is_platform_staff: is_platform_staff,
           type: type
         }}
    end
  end

  defp validate_actor(_), do: {:error, :invalid_actor}
end
