defmodule Voelgoedevents.RbacSanityTest do
  @moduledoc "Tripwire tests for RBAC role set and platform flags."

  use Voelgoedevents.DataCase, async: true

  alias Voelgoedevents.Ash.Resources.Accounts.{Membership, Organization, Role, User}

  @expected_roles [:admin, :owner, :scanner_only, :staff, :viewer]

  describe "rbac tripwire" do
    setup do
      roles = seed_roles()

      {:ok, org} =
        Ash.create(Organization, :create, %{name: "RBAC Org", slug: unique_slug()}, authorize?: false)

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

    test "platform flags gate membership management", %{actors: actors, staff_membership: membership} do
      assert actors.super_admin.is_platform_admin
      refute actors.platform_staff_admin.is_platform_admin
      assert actors.platform_staff_admin.is_platform_staff

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.destroy(membership, :remove, actor: actors.tenant_admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.destroy(membership, :remove, actor: actors.platform_staff_admin)

      assert {:ok, _} = Ash.destroy(membership, :remove, actor: actors.super_admin)
    end

    test "platform staff admins still read within their org", %{actors: actors, staff_membership: membership} do
      assert {:ok, _} =
               Ash.read_one(Membership, filter: [id: membership.id], actor: actors.platform_staff_admin)
    end
  end

  defp seed_roles do
    Enum.reduce(@expected_roles, %{}, fn name, acc ->
      {:ok, role} =
        Ash.create(Role, :create, %{name: name, description: "#{name} role"}, authorize?: false)

      Map.put(acc, name, role)
    end)
  end

  defp create_user(prefix, organization, role, opts \\ []) do
    is_platform_admin = Keyword.get(opts, :is_platform_admin, false)
    is_platform_staff = Keyword.get(opts, :is_platform_staff, false)

    Ash.create(User, :create, %{
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
    }, authorize?: false)
  end

  defp membership_for(user, organization) do
    Ash.read_one(Membership,
      filter: [user_id: user.id, organization_id: organization.id],
      authorize?: false
    )
  end

  defp actor(user, organization, role) do
    %{
      id: user.id,
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
