defmodule Voelgoedevents.Ash.Support.ActorUtils do
  @moduledoc """
  Canonical actor normalization and validation utilities for Ash 3.x.

  Normalizes any incoming actor shape to the canonical 6-field actor map:

      %{
        user_id: uuid,  # Always UUID string (system actors use constant UUID; device/api_key actors use deterministic UUID v5 derivation)
        organization_id: uuid | nil,
        role: :owner | :admin | :staff | :viewer | :scanner_only | nil,
        is_platform_admin: boolean(),
        is_platform_staff: boolean(),
        type: :user | :system | :device | :api_key
      }

  Any missing or invalid field returns `{:error, :invalid_actor}`; use
  `normalize!/1` when you want a hard failure.

  Identity stability:
  - System actors: Always use canonical constant UUID (`system_actor_user_id/0`)
  - Device actors: Deterministic UUID v5 derived from `device_id` (or use `device_id` if already UUID)
  - API key actors: Deterministic UUID v5 derived from `api_key_id` (or use `api_key_id` if already UUID)
  - User actors: Preserve explicit `user_id` (must be valid UUID format)
  """

  @type actor_type :: :user | :device | :api_key | :system
  @type role_type :: :owner | :admin | :staff | :viewer | :scanner_only | nil

  @type actor :: %{
          user_id: String.t(),
          organization_id: String.t() | nil,
          role: role_type,
          is_platform_admin: boolean(),
          is_platform_staff: boolean(),
          type: actor_type
        }

  @roles [:owner, :admin, :staff, :viewer, :scanner_only]
  @types [:user, :system, :device, :api_key]

  # Canonical system actor UUID (stable identity for all system actors)
  # This ensures system actions are attributable and audit trails are consistent
  @system_actor_user_id "00000000-0000-0000-0000-000000000001"

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

  @doc """
  Returns the canonical system actor user_id (stable UUID for all system actors).

  Use this when constructing system actors to ensure consistent identity across calls.
  """
  def system_actor_user_id, do: @system_actor_user_id

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
    # Normalize type first to determine if we need to derive a UUID for system/device/api_key actors
    type = normalize_type(map)

    # Extract user_id - if missing and type is system/device/api_key, derive stable UUID
    # Never use "system" string - always use UUID
    # Never generate random UUIDs - use stable derivations to prevent identity drift
    user_id =
      case {Map.get(map, :user_id) || Map.get(map, :id) || Map.get(map, :actor_id), type} do
        {nil, :system} ->
          # Use canonical system actor UUID (stable across all system actions)
          @system_actor_user_id

        {nil, :device} ->
          # Derive UUID from device_id if available (deterministic)
          case Map.get(map, :device_id) do
            device_id when is_binary(device_id) ->
              # Use device_id as user_id if it's a UUID, otherwise generate deterministic UUID from it
              if String.match?(
                   device_id,
                   ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
                 ) do
                device_id
              else
                # Deterministic UUID v5 from device_id (namespace + device_id)
                # Using namespace UUID for devices: 00000000-0000-0000-0000-000000000002
                derive_uuid_from_string("00000000-0000-0000-0000-000000000002", device_id)
              end

            _ ->
              nil
          end

        {nil, :api_key} ->
          # Derive UUID from api_key_id if available (deterministic)
          case Map.get(map, :api_key_id) do
            api_key_id when is_binary(api_key_id) ->
              # Use api_key_id as user_id if it's a UUID, otherwise generate deterministic UUID from it
              if String.match?(
                   api_key_id,
                   ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
                 ) do
                api_key_id
              else
                # Deterministic UUID v5 from api_key_id (namespace + api_key_id)
                # Using namespace UUID for API keys: 00000000-0000-0000-0000-000000000003
                derive_uuid_from_string("00000000-0000-0000-0000-000000000003", api_key_id)
              end

            _ ->
              nil
          end

        {id, _} when is_binary(id) ->
          id

        _ ->
          nil
      end

    %{
      user_id: user_id,
      organization_id: Map.get(map, :organization_id) || Map.get(map, :org_id),
      role: normalize_role(map),
      is_platform_admin:
        Map.get(map, :is_platform_admin, Map.get(map, :is_platform_admin?, false)),
      is_platform_staff:
        Map.get(map, :is_platform_staff, Map.get(map, :is_platform_staff?, false)),
      type: type
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
      # Note: Never check actor_id == "system" - type must be explicit
      # If type is missing and no device/api_key markers, default to :user
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

      # UUID format validation: user_id must be a valid UUID string
      not valid_uuid?(user_id) ->
        {:error, :invalid_actor}

      # Role validation: nil roles are allowed for system/device/api_key actors
      # For user actors, role must be in @roles unless platform_admin
      role not in @roles and
        not (is_platform_admin and is_nil(role)) and
          not (type in [:system, :device, :api_key] and is_nil(role)) ->
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

  # ------------------------------------------------------------
  # UUID Format Validation
  # ------------------------------------------------------------

  @doc false
  # Validates that a string is a valid UUID format (RFC 4122)
  # Uses Ecto.UUID.cast/1 for canonical validation
  defp valid_uuid?(uuid_string) when is_binary(uuid_string) do
    case Ecto.UUID.cast(uuid_string) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp valid_uuid?(_), do: false

  # ------------------------------------------------------------
  # Stable UUID Derivation (prevents identity drift)
  # ------------------------------------------------------------

  @doc false
  # Derives a deterministic UUID v5 from a namespace UUID and a string (RFC 4122 compliant)
  # This ensures the same input always produces the same UUID
  #
  # UUID v5 specification:
  # - Uses SHA-1 hash (160 bits, we use first 128 bits)
  # - Version bits (12-15 of time_hi_and_version): 0x5 (0101)
  # - Variant bits (14-15 of clock_seq_hi_and_reserved): 0x8xxx (10xx = RFC 4122)
  defp derive_uuid_from_string(namespace_uuid, input) do
    import Bitwise

    # UUID v5 uses SHA-1 (RFC 4122 section 4.3)
    namespace_bytes = uuid_to_binary(namespace_uuid)
    sha1_hash = :crypto.hash(:sha, [namespace_bytes, input])

    # SHA-1 produces 160 bits (20 bytes); UUID needs 128 bits (16 bytes)
    # Read hash as big-endian integers (UUIDs are big-endian)
    # UUID structure: time_low (32), time_mid (16), time_hi_and_version (16), clock_seq_hi_and_reserved (16), node (48)
    <<u0::32-big, u1::16-big, u2::16-big, u3::16-big, u4::48-big, _::binary>> = sha1_hash

    # Set version bits (12-15) to 0x5 for UUID v5 in time_hi_and_version field (u2)
    # Mask: 0x0FFF clears bits 12-15, then OR with 0x5000 sets version to 5
    u2_with_version = (u2 &&& 0x0FFF) ||| 0x5000

    # Set variant bits (14-15) to 10xx (RFC 4122) in clock_seq_hi_and_reserved field (u3)
    # Mask: 0x3FFF clears bits 14-15, then OR with 0x8000 sets variant to RFC 4122
    u3_with_variant = (u3 &&& 0x3FFF) ||| 0x8000

    format_uuid(
      <<u0::32-big, u1::16-big, u2_with_version::16-big, u3_with_variant::16-big, u4::48-big>>
    )
  end

  defp uuid_to_binary(uuid_string) do
    uuid_string
    |> String.replace("-", "")
    |> Base.decode16!(case: :lower)
  end

  defp format_uuid(<<u0::32, u1::16, u2::16, u3::16, u4::48>>) do
    <<u0::32-big, u1::16-big, u2::16-big, u3::16-big, u4::48-big>>
    |> Base.encode16(case: :lower)
    |> then(fn hex ->
      <<a::binary-size(8), b::binary-size(4), c::binary-size(4), d::binary-size(4),
        e::binary-size(12)>> = hex

      "#{a}-#{b}-#{c}-#{d}-#{e}"
    end)
  end
end
