defmodule Voelgoedevents.Ash.Support.ActorUtilsTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias Voelgoedevents.Ash.Support.ActorUtils

  describe "system_actor_user_id/0" do
    test "returns stable canonical system UUID" do
      uuid = ActorUtils.system_actor_user_id()

      assert uuid == "00000000-0000-0000-0000-000000000001"
      assert is_binary(uuid)
      assert String.match?(uuid, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i)

      # Stability: same call returns same value
      assert ActorUtils.system_actor_user_id() == uuid
    end
  end

  describe "normalize/1 - system actor identity stability" do
    test "system actor without user_id gets canonical system UUID" do
      actor = %{
        type: :system,
        organization_id: Ecto.UUID.generate(),
        role: nil,
        is_platform_admin: true,
        is_platform_staff: false
      }

      {:ok, normalized} = ActorUtils.normalize(actor)

      assert normalized.user_id == ActorUtils.system_actor_user_id()
      assert normalized.type == :system
      assert normalized.role == nil
    end

    test "system actor with explicit user_id preserves it" do
      custom_uuid = Ecto.UUID.generate()

      actor = %{
        type: :system,
        user_id: custom_uuid,
        organization_id: Ecto.UUID.generate(),
        role: nil,
        is_platform_admin: true,
        is_platform_staff: false
      }

      {:ok, normalized} = ActorUtils.normalize(actor)

      assert normalized.user_id == custom_uuid
      assert normalized.type == :system
    end

    test "same system actor input produces same normalized user_id" do
      org_id = Ecto.UUID.generate()

      actor1 = %{
        type: :system,
        organization_id: org_id,
        role: nil,
        is_platform_admin: true,
        is_platform_staff: false
      }

      actor2 = %{
        type: :system,
        organization_id: org_id,
        role: nil,
        is_platform_admin: true,
        is_platform_staff: false
      }

      {:ok, norm1} = ActorUtils.normalize(actor1)
      {:ok, norm2} = ActorUtils.normalize(actor2)

      # Same input produces same user_id (canonical system UUID)
      assert norm1.user_id == norm2.user_id
      assert norm1.user_id == ActorUtils.system_actor_user_id()
    end
  end

  describe "normalize/1 - device actor identity stability" do
    test "device actor with UUID device_id uses device_id as user_id" do
      device_uuid = Ecto.UUID.generate()

      actor = %{
        type: :device,
        device_id: device_uuid,
        organization_id: Ecto.UUID.generate(),
        role: nil,
        is_platform_admin: false,
        is_platform_staff: false
      }

      {:ok, normalized} = ActorUtils.normalize(actor)

      assert normalized.user_id == device_uuid
      assert normalized.type == :device
    end

    test "device actor with non-UUID device_id derives stable UUID v5" do
      device_id = "device-12345"
      namespace_uuid = "00000000-0000-0000-0000-000000000002"

      actor = %{
        type: :device,
        device_id: device_id,
        organization_id: Ecto.UUID.generate(),
        role: nil,
        is_platform_admin: false,
        is_platform_staff: false
      }

      {:ok, normalized1} = ActorUtils.normalize(actor)
      {:ok, normalized2} = ActorUtils.normalize(actor)

      # Same device_id produces same derived UUID
      assert normalized1.user_id == normalized2.user_id
      assert is_binary(normalized1.user_id)
      assert String.match?(normalized1.user_id, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i)

      # Verify UUID v5 format: version bit (5) and variant bit (RFC 4122)
      uuid_parts = String.split(normalized1.user_id, "-")
      [_, _, time_hi, clock_seq, _] = uuid_parts
      time_hi_int = String.to_integer(time_hi, 16)
      clock_seq_int = String.to_integer(clock_seq, 16)

      # Version 5: bits 12-15 = 0x5
      assert (time_hi_int &&& 0xF000) == 0x5000

      # Variant RFC 4122: bits 14-15 = 10xx (0x8xxx)
      assert (clock_seq_int &&& 0xC000) == 0x8000
    end

    test "different device_ids produce different UUIDs" do
      actor1 = %{
        type: :device,
        device_id: "device-12345",
        organization_id: Ecto.UUID.generate(),
        role: nil,
        is_platform_admin: false,
        is_platform_staff: false
      }

      actor2 = %{
        type: :device,
        device_id: "device-67890",
        organization_id: Ecto.UUID.generate(),
        role: nil,
        is_platform_admin: false,
        is_platform_staff: false
      }

      {:ok, norm1} = ActorUtils.normalize(actor1)
      {:ok, norm2} = ActorUtils.normalize(actor2)

      assert norm1.user_id != norm2.user_id
    end
  end

  describe "normalize/1 - api_key actor identity stability" do
    test "api_key actor with UUID api_key_id uses api_key_id as user_id" do
      api_key_uuid = Ecto.UUID.generate()

      actor = %{
        type: :api_key,
        api_key_id: api_key_uuid,
        organization_id: Ecto.UUID.generate(),
        role: nil,
        is_platform_admin: false,
        is_platform_staff: false
      }

      {:ok, normalized} = ActorUtils.normalize(actor)

      assert normalized.user_id == api_key_uuid
      assert normalized.type == :api_key
    end

    test "api_key actor with non-UUID api_key_id derives stable UUID v5" do
      api_key_id = "api-key-abc123"

      actor = %{
        type: :api_key,
        api_key_id: api_key_id,
        organization_id: Ecto.UUID.generate(),
        role: nil,
        is_platform_admin: false,
        is_platform_staff: false
      }

      {:ok, normalized1} = ActorUtils.normalize(actor)
      {:ok, normalized2} = ActorUtils.normalize(actor)

      # Same api_key_id produces same derived UUID
      assert normalized1.user_id == normalized2.user_id
      assert is_binary(normalized1.user_id)
      assert String.match?(normalized1.user_id, ~r/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i)

      # Verify UUID v5 format
      uuid_parts = String.split(normalized1.user_id, "-")
      [_, _, time_hi, clock_seq, _] = uuid_parts
      time_hi_int = String.to_integer(time_hi, 16)
      clock_seq_int = String.to_integer(clock_seq, 16)

      # Version 5: bits 12-15 = 0x5
      assert (time_hi_int &&& 0xF000) == 0x5000

      # Variant RFC 4122: bits 14-15 = 10xx (0x8xxx)
      assert (clock_seq_int &&& 0xC000) == 0x8000
    end

    test "different api_key_ids produce different UUIDs" do
      actor1 = %{
        type: :api_key,
        api_key_id: "api-key-123",
        organization_id: Ecto.UUID.generate(),
        role: nil,
        is_platform_admin: false,
        is_platform_staff: false
      }

      actor2 = %{
        type: :api_key,
        api_key_id: "api-key-456",
        organization_id: Ecto.UUID.generate(),
        role: nil,
        is_platform_admin: false,
        is_platform_staff: false
      }

      {:ok, norm1} = ActorUtils.normalize(actor1)
      {:ok, norm2} = ActorUtils.normalize(actor2)

      assert norm1.user_id != norm2.user_id
    end
  end

  describe "normalize/1 - user actor preserves user_id" do
    test "user actor preserves explicit user_id" do
      user_uuid = Ecto.UUID.generate()

      actor = %{
        type: :user,
        user_id: user_uuid,
        organization_id: Ecto.UUID.generate(),
        role: :admin,
        is_platform_admin: false,
        is_platform_staff: false
      }

      {:ok, normalized} = ActorUtils.normalize(actor)

      assert normalized.user_id == user_uuid
      assert normalized.type == :user
    end
  end
end
