defmodule Voelgoedevents.Ash.AccountsTest do
  @moduledoc "Basic tests for accounts domain."

  use Voelgoedevents.DataCase, async: true

  alias Voelgoedevents.Ash.Resources.Accounts.Organization
  alias Voelgoedevents.Ash.Resources.Accounts.Role
  alias Voelgoedevents.Ash.Resources.Organizations.OrganizationSettings

  defp platform_admin_actor(overrides \\ %{}) do
    Map.merge(
      %{
        id: Ecto.UUID.generate(),
        organization_id: nil,
        role: nil,
        is_platform_admin: true,
        is_platform_staff: false,
        type: :user
      },
      overrides
    )
  end

  defp tenant_actor(org_id, role) do
    %{
      id: Ecto.UUID.generate(),
      organization_id: org_id,
      role: role,
      is_platform_admin: false,
      is_platform_staff: false,
      type: :user
    }
  end

  describe "placeholder" do
    test "true is true" do
      assert true
    end
  end

  describe "roles" do
    test "expose canonical display name and permissions" do
      {:ok, role} =
        Ash.create(Role, :create, %{
          name: :admin,
          display_name: "Temp Name",
          permissions: ["temporary_permission"]
        }, actor: %{is_platform_admin: true})

      assert role.display_name == "Admin"

      assert role.permissions == [
               "manage_tenant_users",
               "manage_events_and_venues",
               "manage_ticketing_and_pricing",
               "view_financials",
               "manage_devices",
               "view_full_analytics"
             ]
    end
  end

  describe "organization settings" do
    test "are created with typed attributes and updated via organization" do
      actor = %{
        id: Ecto.UUID.generate(),
        organization_id: nil,
        role: nil,
        is_platform_admin: true,
        is_platform_staff: false,
        type: :user
      }

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
      actor = %{
        id: Ecto.UUID.generate(),
        organization_id: nil,
        role: nil,
        is_platform_admin: true,
        is_platform_staff: false,
        type: :user
      }

      organization =
        Ash.create!(Organization, :create, %{name: "Solo Org", slug: "solo-org"}, actor: actor)

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               Ash.create(OrganizationSettings, :create, %{organization_id: organization.id},
                 actor: %{
                   id: Ecto.UUID.generate(),
                   organization_id: organization.id,
                   role: :owner,
                   is_platform_admin: false,
                   is_platform_staff: false,
                   type: :user
                 }
               )

      assert Enum.any?(errors, &(&1.field == :organization_id))
    end

    test "platform admin can create settings for any organization" do
      platform = platform_admin_actor()

      {:ok, org} =
        Ash.create(Organization, :create, %{name: "Org S", slug: "org-s"}, actor: platform)

      assert {:ok, settings} =
               Ash.create(OrganizationSettings, :create, %{
                 organization_id: org.id,
                 currency: :USD,
                 timezone: "Africa/Johannesburg"
               }, actor: platform)

      assert settings.organization_id == org.id
    end

    test "owner can create and update organization settings for their org" do
      platform = platform_admin_actor()

      {:ok, org} =
        Ash.create(Organization, :create, %{name: "Org T", slug: "org-t"}, actor: platform)

      owner = tenant_actor(org.id, :owner)

      {:ok, settings} =
        Ash.create(OrganizationSettings, :create, %{
          organization_id: org.id,
          currency: :USD,
          timezone: "Africa/Johannesburg"
        }, actor: owner)

      assert {:ok, updated} =
               Ash.update(settings, :update, %{currency: :EUR}, actor: owner)

      assert updated.currency == :EUR
    end

    test "staff and viewer cannot create or update organization settings" do
      platform = platform_admin_actor()

      {:ok, org} =
        Ash.create(Organization, :create, %{name: "Org U", slug: "org-u"}, actor: platform)

      staff = tenant_actor(org.id, :staff)
      viewer = tenant_actor(org.id, :viewer)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.create(OrganizationSettings, :create, %{
                 organization_id: org.id,
                 currency: :USD
               }, actor: staff)

      {:ok, settings} =
        Ash.create(OrganizationSettings, :create, %{
          organization_id: org.id,
          currency: :USD
        }, actor: platform)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.update(settings, :update, %{currency: :EUR}, actor: staff)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.update(settings, :update, %{currency: :EUR}, actor: viewer)
    end

    test "viewer can read organization settings but not modify" do
      platform = platform_admin_actor()

      {:ok, org} =
        Ash.create(Organization, :create, %{name: "Org V", slug: "org-v"}, actor: platform)

      {:ok, settings} =
        Ash.create(OrganizationSettings, :create, %{
          organization_id: org.id,
          currency: :USD
        }, actor: platform)

      viewer = tenant_actor(org.id, :viewer)

      assert {:ok, loaded} = Ash.load(settings, [], actor: viewer)
      assert loaded.currency == :USD

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.update(settings, :update, %{currency: :EUR}, actor: viewer)
    end

    test "unauthenticated actor cannot read or write organization settings" do
      platform = platform_admin_actor()

      {:ok, org} =
        Ash.create(Organization, :create, %{name: "Org W", slug: "org-w"}, actor: platform)

      {:ok, settings} =
        Ash.create(OrganizationSettings, :create, %{
          organization_id: org.id,
          currency: :USD
        }, actor: platform)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.load(settings, [], actor: nil)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.update(settings, :update, %{currency: :EUR}, actor: nil)
    end
  end

  describe "organization rbac" do
    test "platform admin can create organizations" do
      actor = platform_admin_actor()

      assert {:ok, org} =
               Ash.create(Organization, :create, %{
                 name: "Org A",
                 slug: "org-a"
               }, actor: actor)

      assert org.name == "Org A"
    end

    test "non-admin tenant cannot create organizations" do
      actor = tenant_actor(Ecto.UUID.generate(), :owner)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.create(Organization, :create, %{
                 name: "Org B",
                 slug: "org-b"
               }, actor: actor)
    end

    test "owner in org can update its organization" do
      platform = platform_admin_actor()

      {:ok, org} =
        Ash.create(Organization, :create, %{
          name: "Org C",
          slug: "org-c"
        }, actor: platform)

      owner = tenant_actor(org.id, :owner)

      assert {:ok, updated} =
               Ash.update(org, :update, %{name: "Org C Updated"}, actor: owner)

      assert updated.name == "Org C Updated"
    end

    test "admin in another org cannot update this organization" do
      platform = platform_admin_actor()

      {:ok, org_a} =
        Ash.create(Organization, :create, %{name: "Org A", slug: "org-a"}, actor: platform)

      {:ok, org_b} =
        Ash.create(Organization, :create, %{name: "Org B", slug: "org-b"}, actor: platform)

      foreign_admin = tenant_actor(org_b.id, :admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.update(org_a, :update, %{name: "Hacked"}, actor: foreign_admin)
    end

    test "tenant actor can read only their own organization" do
      platform = platform_admin_actor()

      {:ok, org_a} =
        Ash.create(Organization, :create, %{name: "Org A", slug: "org-a"}, actor: platform)

      {:ok, org_b} =
        Ash.create(Organization, :create, %{name: "Org B", slug: "org-b"}, actor: platform)

      actor_a = tenant_actor(org_a.id, :viewer)

      assert {:ok, _} = Ash.load(org_a, [], actor: actor_a)
      assert {:error, %Ash.Error.Forbidden{}} = Ash.load(org_b, [], actor: actor_a)
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

