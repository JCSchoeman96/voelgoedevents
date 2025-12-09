defmodule Voelgoedevents.Ash.AccountsTest do
  @moduledoc "Basic tests for accounts domain."

  use Voelgoedevents.DataCase, async: true

  alias Voelgoedevents.Ash.Resources.Accounts.Organization
  alias Voelgoedevents.Ash.Resources.Organizations.OrganizationSettings

  describe "placeholder" do
    test "true is true" do
      assert true
    end
  end

  describe "organization settings" do
    test "are created with typed attributes and updated via organization" do
      actor = %{role: :super_admin}

      {:ok, organization} =
        Ash.create(Organization, :create, %{
          name: "Acme Corp",
          slug: "acme-corp",
          settings: %{
            currency: :USD,
            timezone: "Africa/Johannesburg",
            primary_color: "#ff9900",
            logo_url: "https://example.com/logo.png"
          }
        }, actor: actor)

      loaded = Ash.load!(organization, :settings, actor: actor)

      assert loaded.settings.currency == :USD
      assert loaded.settings.timezone == "Africa/Johannesburg"
      assert loaded.settings.primary_color == "#ff9900"
      assert loaded.settings.logo_url == "https://example.com/logo.png"

      {:ok, updated} =
        Ash.update(organization, :update, %{settings: %{currency: :EUR, timezone: "UTC"}}, actor: actor)

      updated_loaded = Ash.load!(updated, :settings, actor: actor)

      assert updated_loaded.settings.currency == :EUR
      assert updated_loaded.settings.timezone == "UTC"
    end

    test "enforces one-to-one settings per organization" do
      actor = %{role: :super_admin}

      organization =
        Ash.create!(Organization, :create, %{name: "Solo Org", slug: "solo-org"}, actor: actor)

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Ash.create(OrganizationSettings, :create, %{organization_id: organization.id},
                 actor: %{organization_id: organization.id}
               )

      assert Enum.any?(errors, &(&1.field == :organization_id))
    end
  end

  describe "register_tenant" do
    setup do
      # Ensure owner role exists (normally seeded)
      alias Voelgoedevents.Ash.Resources.Accounts.Role

      case Ash.read_one(Role, filter: [name: :owner], authorize?: false) do
        {:ok, nil} ->
          Ash.create!(Role, :create, %{name: :owner, display_name: "Owner"}, authorize?: false)

        {:ok, _role} ->
          :ok
      end

      :ok
    end

    test "atomically creates organization, owner user, and membership" do
      {:ok, org} =
        Ash.create(Organization, :register_tenant, %{
          organization_name: "Test Corp",
          organization_slug: "test-corp-#{System.unique_integer([:positive])}",
          owner_email: "owner@test.com",
          owner_password: "SecurePassword123!",
          owner_first_name: "Test",
          owner_last_name: "Owner"
        })

      assert org.name == "Test Corp"
      assert org.status == :active

      # Verify owner user and membership were created
      loaded = Ash.load!(org, [memberships: [:user, :role]], authorize?: false)
      assert length(loaded.memberships) == 1

      membership = hd(loaded.memberships)
      assert membership.status == :active
      assert membership.role.name == :owner
      assert membership.user.email.value == "owner@test.com"
      assert membership.user.first_name == "Test"
      assert membership.user.last_name == "Owner"
      assert membership.user.status == :active
      assert not is_nil(membership.user.confirmed_at)
    end

    test "rejects registration with duplicate slug" do
      unique_id = System.unique_integer([:positive])

      {:ok, _org1} =
        Ash.create(Organization, :register_tenant, %{
          organization_name: "First Corp",
          organization_slug: "dup-slug-#{unique_id}",
          owner_email: "owner1@test.com",
          owner_password: "SecurePassword123!",
          owner_first_name: "First",
          owner_last_name: "Owner"
        })

      assert {:error, _} =
               Ash.create(Organization, :register_tenant, %{
                 organization_name: "Second Corp",
                 organization_slug: "dup-slug-#{unique_id}",
                 owner_email: "owner2@test.com",
                 owner_password: "SecurePassword123!",
                 owner_first_name: "Second",
                 owner_last_name: "Owner"
               })
    end

    test "hashes password correctly" do
      {:ok, org} =
        Ash.create(Organization, :register_tenant, %{
          organization_name: "Hash Test Corp",
          organization_slug: "hash-test-#{System.unique_integer([:positive])}",
          owner_email: "hash@test.com",
          owner_password: "MySecurePass123!",
          owner_first_name: "Hash",
          owner_last_name: "Test"
        })

      loaded = Ash.load!(org, [memberships: :user], authorize?: false)
      user = hd(loaded.memberships).user

      # Verify password was hashed (not stored plaintext)
      assert user.hashed_password != "MySecurePass123!"
      assert Bcrypt.verify_pass("MySecurePass123!", user.hashed_password)
    end
  end
end

