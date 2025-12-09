defmodule Voelgoedevents.Ash.MembershipRbacTest do
  @moduledoc "Membership RBAC policy coverage."

  use Voelgoedevents.DataCase, async: true

  alias Voelgoedevents.Ash.Resources.Accounts.{Membership, Organization, Role, User}

  describe "membership management" do
    setup do
      roles = create_roles()

      {:ok, org} =
        Ash.create(Organization, :create, %{name: "Main Org", slug: unique_slug()}, authorize?: false)

      {:ok, other_org} =
        Ash.create(Organization, :create, %{name: "Other Org", slug: unique_slug()}, authorize?: false)

      {:ok, owner} =
        create_user("owner", org, roles.owner)

      {:ok, admin} =
        create_user("admin", org, roles.admin)

      {:ok, member} =
        create_user("member", other_org, roles.viewer)

      {:ok, platform_staff} =
        create_user("platform-staff", org, roles.staff, is_platform_staff: true)

      {:ok, platform_admin} =
        create_user("platform-admin", org, roles.owner, is_platform_admin: true)

      {:ok,
       %{
         roles: roles,
         org: org,
         other_org: other_org,
         owner: owner,
         admin: admin,
         member: member,
         platform_staff: platform_staff,
         platform_admin: platform_admin
       }}
    end

    test "owner can invite, activate, and remove a member", %{roles: roles, org: org, owner: owner, member: member} do
      owner_actor = actor(owner, org, :owner)

      assert {:ok, invitation} =
               Ash.create(Membership, :invite, %{
                 user_id: member.id,
                 organization_id: org.id,
                 role_id: roles.viewer.id
               }, actor: owner_actor)

      assert {:ok, activated} =
               Ash.update(invitation, :update, %{status: :active}, actor: owner_actor)

      assert {:ok, _} = Ash.destroy(activated, :remove, actor: owner_actor)
    end

    test "admin cannot manage memberships", %{roles: roles, org: org, admin: admin, member: member} do
      admin_actor = actor(admin, org, :admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.create(Membership, :invite, %{
                 user_id: member.id,
                 organization_id: org.id,
                 role_id: roles.staff.id
               }, actor: admin_actor)
    end

    test "tenant owners cannot demote platform staff", %{
      org: org,
      owner: owner,
      platform_staff: platform_staff
    } do
      owner_actor = actor(owner, org, :owner)
      {:ok, staff_membership} = membership_for(platform_staff, org)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.destroy(staff_membership, :remove, actor: owner_actor)
    end

    test "platform admins can manage platform staff", %{
      org: org,
      platform_admin: platform_admin,
      platform_staff: platform_staff
    } do
      platform_admin_actor = actor(platform_admin, org, :owner)
      {:ok, staff_membership} = membership_for(platform_staff, org)

      assert {:ok, _} = Ash.destroy(staff_membership, :remove, actor: platform_admin_actor)
    end

    test "cross-tenant actors cannot read or change memberships", %{
      org: org,
      other_org: other_org,
      owner: owner,
      member: member
    } do
      {:ok, owner_membership} = membership_for(owner, org)
      other_actor = actor(member, other_org, :owner)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.read_one(Membership, filter: [id: owner_membership.id], actor: other_actor)

      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.update(owner_membership, :update, %{status: :inactive}, actor: other_actor)
    end
  end

  defp create_roles do
    [:owner, :admin, :staff, :viewer, :scanner_only]
    |> Enum.map(fn name ->
      {:ok, role} =
        Ash.create(Role, :create, %{name: name, description: "#{name} role"}, authorize?: false)

      {name, role}
    end)
    |> Map.new()
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
      organization_role: role,
      is_platform_admin: Map.get(user, :is_platform_admin, false),
      is_platform_staff: Map.get(user, :is_platform_staff, false)
    }
  end

  defp unique_slug do
    "org-#{System.unique_integer([:positive])}"
  end
end
