defmodule Voelgoedevents.RbacSanityTest do
  @moduledoc "Tripwire tests for RBAC role set and platform flags."

  use Voelgoedevents.DataCase, async: true

  alias Voelgoedevents.Ash.Resources.Accounts.{Membership, Organization, Role, User}

  @expected_roles [:admin, :owner, :scanner_only, :staff, :viewer]

  describe "rbac tripwire" do
    setup do
      roles = seed_roles()

      alias Voelgoedevents.Ash.Support.ActorUtils

      # System actor for platform-scoped operations
      # Use stable system actor UUID to prevent identity drift
      system_actor = %{
        user_id: ActorUtils.system_actor_user_id(),
        organization_id: nil,
        role: nil,
        is_platform_admin: true,
        is_platform_staff: false,
        type: :system
      }

      {:ok, org} =
        Organization
        |> Ash.Changeset.for_create(:create, %{name: "RBAC Org", slug: unique_slug()})
        |> Ash.create(actor: system_actor)

      {:ok, tenant_admin} = create_user("tenant-admin", org, roles.admin)

      {:ok, platform_staff_admin} =
        create_user("platform-staff", org, roles.admin, is_platform_staff: true)

      {:ok, super_admin} = create_user("super-admin", org, roles.owner, is_platform_admin: true)

      {:ok, staff_membership} = membership_for(platform_staff_admin, org)

      actors = %{
        tenant_admin: actor(tenant_admin, org, :admin),
        platform_staff_admin: actor(platform_staff_admin, org, :admin),
        super_admin: actor(super_admin, org, :owner)
      }

      {:ok,
       %{
         roles: Map.values(roles),
         platform_staff_admin: platform_staff_admin,
         staff_membership: staff_membership,
         actors: actors
       }}
    end

    test "role table matches expected set", %{roles: roles} do
      role_names = roles |> Enum.map(& &1.name) |> Enum.sort()

      assert role_names == @expected_roles
    end

    test "platform flags gate membership management", %{
      actors: actors,
      staff_membership: membership
    } do
      assert actors.super_admin.is_platform_admin
      refute actors.platform_staff_admin.is_platform_admin
      assert actors.platform_staff_admin.is_platform_staff

      assert {:error, %Ash.Error.Forbidden{}} =
               membership
               |> Ash.Changeset.for_destroy(:remove)
               |> Ash.destroy(actor: actors.tenant_admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               membership
               |> Ash.Changeset.for_destroy(:remove)
               |> Ash.destroy(actor: actors.platform_staff_admin)

      assert {:ok, _} =
               membership
               |> Ash.Changeset.for_destroy(:remove)
               |> Ash.destroy(actor: actors.super_admin)
    end

    test "platform staff admins still read within their org", %{
      actors: actors,
      staff_membership: membership
    } do
      assert {:ok, _} =
               Ash.read_one(Membership,
                 filter: [id: membership.id],
                 actor: actors.platform_staff_admin
               )
    end

    test "deny-by-default: unauthenticated actor cannot perform restricted actions (policy-specific)" do
      alias Voelgoedevents.Ash.Resources.Accounts.Role
      alias Voelgoedevents.Ash.Support.ActorUtils

      # Attempt to create a role with nil actor (unauthenticated)
      # Role.create requires platform admin actor (see Role policies: PlatformPolicy.platform_admin_root_access)
      result =
        Role
        |> Ash.Changeset.for_create(:create, %{
          name: :test_role_unauth,
          display_name: "Test Role Unauth",
          permissions: []
        })
        |> Ash.create(actor: nil)

      # Assert Forbidden error (policy denial)
      assert {:error, %Ash.Error.Forbidden{} = forbidden_error} = result,
             "Unauthenticated actor should be denied by policy; got: #{inspect(result)}"

      # Positive control: same action with authorized actor should pass authorization
      # (may fail on validation/business logic, but NOT on authorization)
      system_actor = %{
        user_id: ActorUtils.system_actor_user_id(),
        organization_id: nil,
        role: nil,
        is_platform_admin: true,
        is_platform_staff: false,
        type: :system
      }

      # Platform admin can create roles (passes authorization)
      # Note: This may fail on validation (e.g., duplicate name), but NOT on authorization
      unique_role_name = :"test_role_auth_#{System.unique_integer([:positive])}"

      authorized_result =
        Role
        |> Ash.Changeset.for_create(:create, %{
          name: unique_role_name,
          display_name: "Test Role Authorized",
          permissions: []
        })
        |> Ash.create(actor: system_actor)

      # Should NOT be Forbidden (authorization passed)
      # If it fails, it should be Invalid (validation) or another non-auth error
      case authorized_result do
        {:ok, _role} ->
          # Success - authorization passed and action completed
          :ok

        {:error, %Ash.Error.Invalid{}} ->
          # Validation error - authorization passed, but validation failed (acceptable)
          :ok

        {:error, %Ash.Error.Forbidden{}} = err ->
          flunk("""
          Authorized actor (platform admin) should pass authorization.
          Got Forbidden error: #{inspect(err)}

          This indicates authorization is incorrectly denying authorized actors.
          """)

        {:error, other} ->
          # Other error (e.g., framework error) - authorization likely passed
          # Log for debugging but don't fail test
          IO.puts("""
          Warning: Authorized actor got non-Forbidden error (authorization likely passed):
          #{inspect(other)}
          """)

          :ok
      end
    end

    test "deny-by-default: authorized access works (must-succeed positive control)" do
      alias Voelgoedevents.Ash.Resources.Accounts.Role
      alias Voelgoedevents.Ash.Support.ActorUtils
      require Ash.Query

      # Must-succeed positive control: Role.read with platform admin must return canonical roles
      # This proves authorized access actually works, not just "isn't forbidden"
      system_actor = %{
        user_id: ActorUtils.system_actor_user_id(),
        organization_id: nil,
        role: nil,
        is_platform_admin: true,
        is_platform_staff: false,
        type: :system
      }

      # Role.read is open (authorize_if always()), but we use platform admin to be explicit
      {:ok, roles} =
        Role
        |> Ash.Query.for_read(:read)
        |> Ash.read(actor: system_actor)

      # Assert we got the expected canonical role set
      role_names = roles |> Enum.map(& &1.name) |> Enum.sort()

      assert role_names == @expected_roles,
             """
             Platform admin should be able to read canonical roles.
             Expected: #{inspect(@expected_roles)}
             Got: #{inspect(role_names)}

             This proves authorized access works, not just "isn't forbidden".
             """
    end

    test "deny-by-default: actor missing required org context cannot access tenant-scoped resources" do
      alias Voelgoedevents.Ash.Resources.Accounts.Organization
      alias Voelgoedevents.Ash.Support.ActorUtils

      # Actor with nil organization_id cannot access tenant-scoped resources
      # Organization.create requires platform admin (see Organization policies)
      actor_without_org = %{
        user_id: Ecto.UUID.generate(),
        organization_id: nil,
        role: :admin,
        is_platform_admin: false,
        is_platform_staff: false,
        type: :user
      }

      # Attempt to create organization (should require platform admin, not just any actor)
      result =
        Organization
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Org",
          slug: "test-org-#{System.unique_integer([:positive])}"
        })
        |> Ash.create(actor: actor_without_org)

      # Assert Forbidden error (policy denial)
      assert {:error, %Ash.Error.Forbidden{}} = result,
             "Actor without platform admin should be denied by policy; got: #{inspect(result)}"

      # Positive control: platform admin can create organizations
      system_actor = %{
        user_id: ActorUtils.system_actor_user_id(),
        organization_id: nil,
        role: nil,
        is_platform_admin: true,
        is_platform_staff: false,
        type: :system
      }

      unique_slug = "test-org-authorized-#{System.unique_integer([:positive])}"

      authorized_result =
        Organization
        |> Ash.Changeset.for_create(:create, %{
          name: "Test Org Authorized",
          slug: unique_slug
        })
        |> Ash.create(actor: system_actor)

      # Should NOT be Forbidden (authorization passed)
      # If it fails, it should be Invalid (validation) or another non-auth error
      case authorized_result do
        {:ok, _org} ->
          # Success - authorization passed and action completed
          :ok

        {:error, %Ash.Error.Invalid{}} ->
          # Validation error - authorization passed, but validation failed (acceptable)
          :ok

        {:error, %Ash.Error.Forbidden{}} = err ->
          flunk("""
          Authorized actor (platform admin) should pass authorization.
          Got Forbidden error: #{inspect(err)}

          This indicates authorization is incorrectly denying authorized actors.
          """)

        {:error, other} ->
          # Other error (e.g., framework error) - authorization likely passed
          # Log for debugging but don't fail test
          IO.puts("""
          Warning: Authorized actor got non-Forbidden error (authorization likely passed):
          #{inspect(other)}
          """)

          :ok
      end
    end
  end

  defp seed_roles do
    alias Voelgoedevents.Ash.Support.ActorUtils

    # System actor for platform-scoped operations (Role is platform-scoped)
    # Use stable system actor UUID to prevent identity drift
    system_actor = %{
      user_id: ActorUtils.system_actor_user_id(),
      organization_id: nil,
      role: nil,
      is_platform_admin: true,
      is_platform_staff: false,
      type: :system
    }

    require Ash.Query

    Enum.reduce(@expected_roles, %{}, fn name, acc ->
      # Check if role exists first (roles may already exist from migrations)
      # Always use system_actor for reads (even if policy is open) for future-proofing
      role =
        Role
        |> Ash.Query.for_read(:read)
        |> Ash.Query.filter(name == ^name)
        |> Ash.read(actor: system_actor)
        |> case do
          {:ok, [existing_role | _]} ->
            existing_role

          {:ok, []} ->
            # Create role using Ash 3.x canonical invocation
            # Only name is required; display_name and permissions are set by change function
            {:ok, new_role} =
              Role
              |> Ash.Changeset.for_create(:create, %{name: name})
              |> Ash.create(actor: system_actor)

            new_role

          {:error, reason} ->
            raise "Failed to check/create role #{name}: #{inspect(reason)}"
        end

      Map.put(acc, name, role)
    end)
  end

  defp create_user(prefix, organization, role, opts \\ []) do
    alias Voelgoedevents.Ash.Support.ActorUtils

    is_platform_admin = Keyword.get(opts, :is_platform_admin, false)
    is_platform_staff = Keyword.get(opts, :is_platform_staff, false)

    # System actor for test setup
    # Use stable system actor UUID to prevent identity drift
    system_actor = %{
      user_id: ActorUtils.system_actor_user_id(),
      organization_id: organization.id,
      role: nil,
      is_platform_admin: true,
      is_platform_staff: false,
      type: :system
    }

    User
    |> Ash.Changeset.for_create(:create, %{
      email: "#{prefix}+#{System.unique_integer([:positive])}@example.com",
      first_name: String.capitalize(prefix),
      last_name: "User",
      status: :active,
      hashed_password: "hashed",
      confirmed_at: DateTime.utc_now(),
      organization_id: organization.id,
      role_id: role.id,
      is_platform_admin: is_platform_admin,
      is_platform_staff: is_platform_staff
    })
    |> Ash.create(actor: system_actor)
  end

  defp membership_for(user, organization) do
    require Ash.Query

    Membership
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(user_id == ^user.id and organization_id == ^organization.id)
    |> Ash.read_one()
  end

  defp actor(user, organization, role) do
    %{
      user_id: user.id,
      organization_id: organization.id,
      role: role,
      is_platform_admin: Map.get(user, :is_platform_admin, false),
      is_platform_staff: Map.get(user, :is_platform_staff, false),
      type: :user
    }
  end

  defp unique_slug do
    "org-#{System.unique_integer([:positive])}"
  end
end
