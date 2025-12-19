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
          {:ok, [existing_role | _]} -> existing_role
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
