#!/usr/bin/env elixir

# Smoke test for UUID v5 derivation via ActorUtils
# Verifies that ActorUtils.normalize/1 produces stable, correctly-formatted UUIDs
# Run with: mix run priv/scripts/uuid_v5_smoke.exs

alias Voelgoedevents.Ash.Support.ActorUtils

defmodule UUIDV5Smoke do
  def run do
    IO.puts("=" <> String.duplicate("=", 60))
    IO.puts("UUID v5 Derivation Smoke Test")
    IO.puts("Testing ActorUtils.normalize/1 for device/api_key actors")
    IO.puts("=" <> String.duplicate("=", 60))

    # Test device actor with non-UUID device_id
    IO.puts("\n1. Testing device actor with non-UUID device_id...")
    device_id = "device-12345"
    device_actor = %{
      type: :device,
      device_id: device_id,
      organization_id: Ecto.UUID.generate(),
      role: nil,
      is_platform_admin: false,
      is_platform_staff: false
    }

    case ActorUtils.normalize(device_actor) do
      {:ok, normalized1} ->
        IO.puts("   ✓ Normalization succeeded")
        IO.puts("   user_id: #{normalized1.user_id}")

        # Verify UUID format
        v5_pattern = ~r/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
        matches_pattern = String.match?(normalized1.user_id, v5_pattern)
        IO.puts("   Matches UUID v5 pattern: #{matches_pattern}")

        # Verify version and variant bits
        uuid_parts = String.split(normalized1.user_id, "-")
        [_, _, time_hi, clock_seq, _] = uuid_parts
        time_hi_int = String.to_integer(time_hi, 16)
        clock_seq_int = String.to_integer(clock_seq, 16)

        import Bitwise
        version_check = (time_hi_int &&& 0xF000) == 0x5000
        variant_check = (clock_seq_int &&& 0xC000) == 0x8000

        IO.puts("   Version bit (5): #{version_check}")
        IO.puts("   Variant bit (RFC 4122): #{variant_check}")

        # Test stability
        {:ok, normalized2} = ActorUtils.normalize(device_actor)
        stable = normalized1.user_id == normalized2.user_id
        IO.puts("   Stability (same input -> same UUID): #{stable}")

        if matches_pattern and version_check and variant_check and stable do
          IO.puts("   ✅ Device actor test passed")
        else
          IO.puts("   ❌ Device actor test failed")
          System.halt(1)
        end

      {:error, reason} ->
        IO.puts("   ❌ Normalization failed: #{inspect(reason)}")
        System.halt(1)
    end

    # Test API key actor with non-UUID api_key_id
    IO.puts("\n2. Testing API key actor with non-UUID api_key_id...")
    api_key_id = "api-key-abc123"
    api_key_actor = %{
      type: :api_key,
      api_key_id: api_key_id,
      organization_id: Ecto.UUID.generate(),
      role: nil,
      is_platform_admin: false,
      is_platform_staff: false
    }

    case ActorUtils.normalize(api_key_actor) do
      {:ok, normalized1} ->
        IO.puts("   ✓ Normalization succeeded")
        IO.puts("   user_id: #{normalized1.user_id}")

        # Verify UUID format
        v5_pattern = ~r/^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
        matches_pattern = String.match?(normalized1.user_id, v5_pattern)
        IO.puts("   Matches UUID v5 pattern: #{matches_pattern}")

        # Verify version and variant bits
        uuid_parts = String.split(normalized1.user_id, "-")
        [_, _, time_hi, clock_seq, _] = uuid_parts
        time_hi_int = String.to_integer(time_hi, 16)
        clock_seq_int = String.to_integer(clock_seq, 16)

        import Bitwise
        version_check = (time_hi_int &&& 0xF000) == 0x5000
        variant_check = (clock_seq_int &&& 0xC000) == 0x8000

        IO.puts("   Version bit (5): #{version_check}")
        IO.puts("   Variant bit (RFC 4122): #{variant_check}")

        # Test stability
        {:ok, normalized2} = ActorUtils.normalize(api_key_actor)
        stable = normalized1.user_id == normalized2.user_id
        IO.puts("   Stability (same input -> same UUID): #{stable}")

        if matches_pattern and version_check and variant_check and stable do
          IO.puts("   ✅ API key actor test passed")
        else
          IO.puts("   ❌ API key actor test failed")
          System.halt(1)
        end

      {:error, reason} ->
        IO.puts("   ❌ Normalization failed: #{inspect(reason)}")
        System.halt(1)
    end

    # Test system actor uses constant UUID
    IO.puts("\n3. Testing system actor uses constant UUID...")
    system_actor = %{
      type: :system,
      organization_id: Ecto.UUID.generate(),
      role: nil,
      is_platform_admin: true,
      is_platform_staff: false
    }

    case ActorUtils.normalize(system_actor) do
      {:ok, normalized} ->
        expected_uuid = ActorUtils.system_actor_user_id()
        matches_constant = normalized.user_id == expected_uuid
        IO.puts("   user_id: #{normalized.user_id}")
        IO.puts("   Expected: #{expected_uuid}")
        IO.puts("   Matches constant: #{matches_constant}")

        if matches_constant do
          IO.puts("   ✅ System actor test passed")
        else
          IO.puts("   ❌ System actor test failed")
          System.halt(1)
        end

      {:error, reason} ->
        IO.puts("   ❌ Normalization failed: #{inspect(reason)}")
        System.halt(1)
    end

    # Test UUID format validation rejects invalid strings
    IO.puts("\n4. Testing UUID format validation...")
    invalid_actor = %{
      type: :user,
      user_id: "not-a-uuid",
      organization_id: Ecto.UUID.generate(),
      role: :admin,
      is_platform_admin: false,
      is_platform_staff: false
    }

    case ActorUtils.normalize(invalid_actor) do
      {:error, :invalid_actor} ->
        IO.puts("   ✓ Invalid UUID correctly rejected")
        IO.puts("   ✅ UUID validation test passed")
      {:ok, _} ->
        IO.puts("   ❌ Invalid UUID was accepted (should be rejected)")
        System.halt(1)
    end

    IO.puts("\n" <> String.duplicate("=", 62))
    IO.puts("✅ All smoke tests passed!")
    IO.puts(String.duplicate("=", 62))
  end
end

UUIDV5Smoke.run()
