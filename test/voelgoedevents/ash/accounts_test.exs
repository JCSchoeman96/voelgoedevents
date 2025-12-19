defmodule Voelgoedevents.Ash.AccountsTest do
  @moduledoc "Basic tests for accounts domain."

  use Voelgoedevents.DataCase, async: true

  alias Voelgoedevents.Ash.Resources.Accounts.Organization
  alias Voelgoedevents.Ash.Resources.Accounts.Role
  alias Voelgoedevents.Ash.Resources.Organizations.OrganizationSettings

  alias Ash.Query, as: Query
  require Query

  #
  # ACTOR HELPERS (CORRECT SHAPE FOR ASH 3.x POLICIES)
  #
  defp platform_admin_actor(overrides \\ %{}) do
    Map.merge(
      %{
        user_id: Ecto.UUID.generate(),
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
      user_id: Ecto.UUID.generate(),
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

  # --------------------------------------------------------------------
  # ROLE TESTS
  # --------------------------------------------------------------------
  describe "roles" do
    test "expose canonical display name and permissions" do
      actor = platform_admin_actor()

      role =
        Role
        |> Ash.Changeset.for_create(:create, %{
          name: :admin,
          display_name: "Temp Name",
          permissions: ["temporary_permission"]
        })
        |> Ash.create(actor: actor)
        |> case do
          {:ok, role} ->
            role

          {:error, %Ash.Error.Invalid{errors: errors} = error} ->
            duplicate_name? =
              Enum.any?(errors, fn
                %Ash.Error.Changes.InvalidAttribute{field: :name, private_vars: private_vars} ->
                  Keyword.get(private_vars, :constraint_type) == :unique and
                    Keyword.get(private_vars, :constraint) in [
                      "roles_name_index",
                      "roles_unique_name_index"
                    ]

                _ ->
                  false
              end)

            if duplicate_name? do
              Role
              |> Ash.Query.filter(name == :admin)
              |> Ash.read_one!(actor: actor)
            else
              raise error
            end

          {:error, error} ->
            raise error
        end

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

  # --------------------------------------------------------------------
  # ORGANIZATION SETTINGS
  # --------------------------------------------------------------------
  describe "organization settings" do
    test "are created with typed attributes and updated via organization" do
      actor = platform_admin_actor()

      {:ok, organization} =
        Organization
        |> Ash.Changeset.for_create(:create, %{
          name: "Acme Corp",
          slug: "acme-corp",
          settings: %{
            currency: :USD,
            timezone: "Africa/Johannesburg",
            primary_color: "#ff9900",
            logo_url: "https://example.com/logo.png"
          }
        })
        |> Ash.create(actor: actor)

      scoped_actor =
        platform_admin_actor(%{
          user_id: actor.user_id,
          organization_id: organization.id
        })

      loaded = Ash.load!(organization, :settings, actor: scoped_actor)

      assert loaded.settings.currency == :USD
      assert loaded.settings.timezone == "Africa/Johannesburg"
      assert loaded.settings.primary_color == "#ff9900"
      assert loaded.settings.logo_url == "https://example.com/logo.png"

      {:ok, updated} =
        organization
        |> Ash.Changeset.for_update(
          :update,
          %{settings: %{currency: :EUR, timezone: "UTC"}},
          actor: scoped_actor
        )
        |> Ash.update()

      updated_loaded = Ash.load!(updated, :settings, actor: scoped_actor)

      assert updated_loaded.settings.currency == :EUR
      assert updated_loaded.settings.timezone == "UTC"
    end

    test "enforces one-to-one settings per organization" do
      actor = platform_admin_actor()

      organization =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Solo Org", slug: "solo-org"})
        |> Ash.create!(actor: actor)

      owner = tenant_actor(organization.id, :owner)

      assert {:ok, _settings} =
               OrganizationSettings
               |> Ash.Changeset.for_create(:create, %{organization_id: organization.id})
               |> Ash.create(actor: owner)

      assert {:error, %Ash.Error.Invalid{errors: errors}} =
               OrganizationSettings
               |> Ash.Changeset.for_create(:create, %{organization_id: organization.id})
               |> Ash.create(actor: owner)

      assert Enum.any?(errors, &(&1.field == :organization_id))
    end

    test "platform admin can create settings for any organization" do
      platform = platform_admin_actor()

      {:ok, org} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org S", slug: "org-s"})
        |> Ash.create(actor: platform)

      assert {:ok, settings} =
               OrganizationSettings
               |> Ash.Changeset.for_create(:create, %{
                 organization_id: org.id,
                 currency: :USD,
                 timezone: "Africa/Johannesburg"
               })
               |> Ash.create(actor: platform)

      assert settings.organization_id == org.id
    end

    test "owner can create and update organization settings for their org" do
      platform = platform_admin_actor()

      {:ok, org} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org T", slug: "org-t"})
        |> Ash.create(actor: platform)

      owner = tenant_actor(org.id, :owner)

      {:ok, settings} =
        OrganizationSettings
        |> Ash.Changeset.for_create(:create, %{
          organization_id: org.id,
          currency: :USD,
          timezone: "Africa/Johannesburg"
        })
        |> Ash.create(actor: owner)

      assert {:ok, updated} =
               settings
               |> Ash.Changeset.for_update(:update, %{currency: :EUR})
               |> Ash.update(actor: owner)

      assert updated.currency == :EUR
    end

    test "staff and viewer cannot create or update organization settings" do
      platform = platform_admin_actor()

      {:ok, org} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org U", slug: "org-u"})
        |> Ash.create(actor: platform)

      staff = tenant_actor(org.id, :staff)
      viewer = tenant_actor(org.id, :viewer)

      # staff cannot create
      assert {:error, %Ash.Error.Forbidden{}} =
               OrganizationSettings
               |> Ash.Changeset.for_create(:create, %{
                 organization_id: org.id,
                 currency: :USD
               })
               |> Ash.create(actor: staff)

      {:ok, settings} =
        OrganizationSettings
        |> Ash.Changeset.for_create(:create, %{
          organization_id: org.id,
          currency: :USD
        })
        |> Ash.create(actor: platform)

      # staff cannot update
      assert {:error, %Ash.Error.Forbidden{}} =
               settings
               |> Ash.Changeset.for_update(:update, %{currency: :EUR})
               |> Ash.update(actor: staff)

      # viewer cannot update
      assert {:error, %Ash.Error.Forbidden{}} =
               settings
               |> Ash.Changeset.for_update(:update, %{currency: :EUR})
               |> Ash.update(actor: viewer)
    end

    test "viewer can read organization settings but not modify" do
      platform = platform_admin_actor()

      {:ok, org} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org V", slug: "org-v"})
        |> Ash.create(actor: platform)

      {:ok, settings} =
        OrganizationSettings
        |> Ash.Changeset.for_create(:create, %{
          organization_id: org.id,
          currency: :USD
        })
        |> Ash.create(actor: platform)

      viewer = tenant_actor(org.id, :viewer)

      assert {:ok, loaded} = Ash.load(settings, [], actor: viewer)
      assert loaded.currency == :USD

      assert {:error, %Ash.Error.Forbidden{}} =
               settings
               |> Ash.Changeset.for_update(:update, %{currency: :EUR})
               |> Ash.update(actor: viewer)
    end

    test "unauthenticated actor cannot read or write organization settings" do
      platform = platform_admin_actor()

      {:ok, org} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org W", slug: "org-w"})
        |> Ash.create(actor: platform)

      {:ok, settings} =
        OrganizationSettings
        |> Ash.Changeset.for_create(:create, %{
          organization_id: org.id,
          currency: :USD
        })
        |> Ash.create(actor: platform)

      assert {:error, %Ash.Error.Forbidden{}} =
               OrganizationSettings
               |> Ash.Query.filter(id == ^settings.id)
               |> Ash.read_one(actor: nil, context: %{organization_id: org.id})

      assert {:error, %Ash.Error.Forbidden{}} =
               settings
               |> Ash.Changeset.for_update(:update, %{currency: :EUR})
               |> Ash.update(actor: nil, context: %{organization_id: org.id})
    end
  end

  # --------------------------------------------------------------------
  # ORGANIZATION RBAC
  # --------------------------------------------------------------------
  describe "organization rbac" do
    test "platform admin can create organizations" do
      actor = platform_admin_actor()

      assert {:ok, org} =
               Organization
               |> Ash.Changeset.for_create(:create, %{name: "Org A", slug: "org-a"})
               |> Ash.create(actor: actor)

      assert org.name == "Org A"
    end

    test "non-admin tenant cannot create organizations" do
      actor = tenant_actor(Ecto.UUID.generate(), :owner)

      assert {:error, %Ash.Error.Forbidden{}} =
               Organization
               |> Ash.Changeset.for_create(:create, %{name: "Org B", slug: "org-b"})
               |> Ash.create(actor: actor)
    end

    test "owner in org can update its organization" do
      platform = platform_admin_actor()

      {:ok, org} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org C", slug: "org-c"})
        |> Ash.create(actor: platform)

      owner = tenant_actor(org.id, :owner)

      assert {:ok, updated} =
               org
               |> Ash.Changeset.for_update(:update, %{name: "Org C Updated"})
               |> Ash.update(actor: owner)

      assert updated.name == "Org C Updated"
    end

    test "admin in another org cannot update this organization" do
      platform = platform_admin_actor()

      {:ok, org_a} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org A", slug: "org-a"})
        |> Ash.create(actor: platform)

      {:ok, org_b} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org B", slug: "org-b"})
        |> Ash.create(actor: platform)

      foreign_admin = tenant_actor(org_b.id, :admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               org_a
               |> Ash.Changeset.for_update(:update, %{name: "Hacked"})
               |> Ash.update(actor: foreign_admin)
    end

    test "tenant actor can read only their own organization" do
      platform = platform_admin_actor()

      {:ok, org_a} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org A", slug: "org-a"})
        |> Ash.create(actor: platform)

      {:ok, org_b} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "Org B", slug: "org-b"})
        |> Ash.create(actor: platform)

      actor_a = tenant_actor(org_a.id, :viewer)

      assert {:ok, _} =
               Organization
               |> Ash.Query.filter(id == ^org_a.id)
               |> Ash.read_one(actor: actor_a, context: %{organization_id: org_a.id})

      assert {:ok, nil} =
               Organization
               |> Ash.Query.filter(id == ^org_b.id)
               |> Ash.read_one(actor: actor_a, context: %{organization_id: org_a.id})
    end
  end

  # --------------------------------------------------------------------
  # REGISTER TENANT TESTS
  # --------------------------------------------------------------------
  describe "register_tenant" do
    @describetag :register_tenant
    setup do
      case Role
           |> Query.filter(name == :owner)
           |> Ash.read_one(authorize?: false) do
        {:ok, nil} ->
          Role
          |> Ash.Changeset.for_create(:create, %{name: :owner, display_name: "Owner"})
          |> Ash.create!(authorize?: false)

        {:ok, _role} ->
          :ok
      end

      :ok
    end

    test "forbids anonymous tenant registration" do
      assert {:error, %Ash.Error.Forbidden{}} =
               Organization
               |> Ash.Changeset.for_create(:register_tenant, %{
                 organization_name: "Forbidden Corp",
                 organization_slug: "forbidden-#{System.unique_integer([:positive])}",
                 owner_email: "forbidden@test.com",
                 owner_password: "SecurePassword123!",
                 owner_first_name: "Forbidden",
                 owner_last_name: "Owner"
               })
               |> Ash.create()
    end

    test "forbids logged-in non-platform-admin tenant registration" do
      actor =
        platform_admin_actor(%{
          user_id: Ash.UUID.generate(),
          is_platform_admin: false,
          role: :viewer,
          organization_id: nil
        })

      assert {:error, %Ash.Error.Forbidden{}} =
               Organization
               |> Ash.Changeset.for_create(:register_tenant, %{
                 organization_name: "Forbidden Corp",
                 organization_slug: "forbidden-user-#{System.unique_integer([:positive])}",
                 owner_email: "forbidden-user@test.com",
                 owner_password: "SecurePassword123!",
                 owner_first_name: "Forbidden",
                 owner_last_name: "Owner"
               })
               |> Ash.create(actor: actor)
    end

    test "allows platform-admin tenant registration" do
      actor =
        platform_admin_actor(%{
          user_id: Ash.UUID.generate(),
          is_platform_admin: true
        })

      assert {:ok, org} =
               Organization
               |> Ash.Changeset.for_create(:register_tenant, %{
                 organization_name: "Allowed Corp",
                 organization_slug: "allowed-#{System.unique_integer([:positive])}",
                 owner_email: "allowed@test.com",
                 owner_password: "SecurePassword123!",
                 owner_first_name: "Allowed",
                 owner_last_name: "Owner"
               })
               |> Ash.create(actor: actor)

      assert org.name == "Allowed Corp"
    end

    test "atomically creates organization, owner user, and membership" do
      actor = platform_admin_actor()

      {:ok, org} =
        Organization
        |> Ash.Changeset.for_create(:register_tenant, %{
          organization_name: "Test Corp",
          organization_slug: "test-corp-#{System.unique_integer([:positive])}",
          owner_email: "owner@test.com",
          owner_password: "SecurePassword123!",
          owner_first_name: "Test",
          owner_last_name: "Owner"
        })
        |> Ash.create(actor: actor)

      assert org.name == "Test Corp"
      assert org.status == :active

      loaded =
        Ash.load!(org, [memberships: [:user, :role]],
          actor: tenant_actor(org.id, :owner),
          authorize?: false
        )

      assert length(loaded.memberships) == 1

      membership = hd(loaded.memberships)
      assert membership.status == :active
      assert membership.role.name == :owner
      assert to_string(membership.user.email) == "owner@test.com"
      assert membership.user.first_name == "Test"
      assert membership.user.last_name == "Owner"
      assert membership.user.status == :active
      assert not is_nil(membership.user.confirmed_at)
    end

    test "rejects registration with duplicate slug" do
      actor = platform_admin_actor()
      unique_id = System.unique_integer([:positive])

      {:ok, _org1} =
        Organization
        |> Ash.Changeset.for_create(:register_tenant, %{
          organization_name: "First Corp",
          organization_slug: "dup-slug-#{unique_id}",
          owner_email: "owner1@test.com",
          owner_password: "SecurePassword123!",
          owner_first_name: "First",
          owner_last_name: "Owner"
        })
        |> Ash.create(actor: actor)

      assert {:error, _} =
               Organization
               |> Ash.Changeset.for_create(:register_tenant, %{
                 organization_name: "Second Corp",
                 organization_slug: "dup-slug-#{unique_id}",
                 owner_email: "owner2@test.com",
                 owner_password: "SecurePassword123!",
                 owner_first_name: "Second",
                 owner_last_name: "Owner"
               })
               |> Ash.create(actor: actor)
    end

    test "hashes password correctly" do
      actor = platform_admin_actor()

      {:ok, org} =
        Organization
        |> Ash.Changeset.for_create(:register_tenant, %{
          organization_name: "Hash Test Corp",
          organization_slug: "hash-test-#{System.unique_integer([:positive])}",
          owner_email: "hash@test.com",
          owner_password: "MySecurePass123!",
          owner_first_name: "Hash",
          owner_last_name: "Test"
        })
        |> Ash.create(actor: actor)

      loaded =
        Ash.load!(org, [memberships: :user],
          actor: tenant_actor(org.id, :owner),
          authorize?: false
        )

      user = hd(loaded.memberships).user

      assert user.hashed_password != "MySecurePass123!"
      assert Bcrypt.verify_pass("MySecurePass123!", user.hashed_password)
    end
  end
end
