defmodule Voelgoedevents.Ash.MembershipRbacTest do
  @moduledoc """
  Membership RBAC policy coverage.

  Tests use direct Repo fixtures to bypass Ash validation complexity,
  focusing purely on policy enforcement behavior.
  """

  use Voelgoedevents.DataCase, async: true

  alias Voelgoedevents.Ash.Resources.Accounts.Membership
  alias Voelgoedevents.TestFixtures

  require Ash.Query

  describe "membership management" do
    setup do
      roles = TestFixtures.ensure_roles()

      org = TestFixtures.create_organization(%{name: "Main Org"})
      other_org = TestFixtures.create_organization(%{name: "Other Org"})

      owner = TestFixtures.create_user(
        %{first_name: "Owner"},
        organization: org,
        role: roles.owner
      )

      admin = TestFixtures.create_user(
        %{first_name: "Admin"},
        organization: org,
        role: roles.admin
      )

      # Member in other_org (for cross-tenant tests)
      member = TestFixtures.create_user(
        %{first_name: "Member"},
        organization: other_org,
        role: roles.viewer
      )

      platform_staff = TestFixtures.create_user(
        %{first_name: "PlatformStaff"},
        organization: org,
        role: roles.staff,
        is_platform_staff: true
      )

      platform_admin = TestFixtures.create_user(
        %{first_name: "PlatformAdmin"},
        organization: org,
        role: roles.owner,
        is_platform_admin: true
      )

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

    test "owner can invite, activate, and remove a member", ctx do
      %{roles: roles, org: org, owner: owner, member: member} = ctx
      owner_actor = TestFixtures.build_actor(owner, org, :owner)

      # Invite
      assert {:ok, invitation} =
               Membership
               |> Ash.Changeset.for_create(:invite, %{
                 user_id: member.id,
                 organization_id: org.id,
                 role_id: roles.viewer.id
               })
               |> Ash.create(actor: owner_actor)

      # Activate
      assert {:ok, activated} =
               invitation
               |> Ash.Changeset.for_update(:update, %{status: :active})
               |> Ash.update(actor: owner_actor)

      # Remove
      assert {:ok, _} =
               activated
               |> Ash.Changeset.for_destroy(:remove)
               |> Ash.destroy(actor: owner_actor)
    end

    test "admin cannot manage memberships", ctx do
      %{roles: roles, org: org, admin: admin, member: member} = ctx
      admin_actor = TestFixtures.build_actor(admin, org, :admin)

      assert {:error, %Ash.Error.Forbidden{}} =
               Membership
               |> Ash.Changeset.for_create(:invite, %{
                 user_id: member.id,
                 organization_id: org.id,
                 role_id: roles.staff.id
               })
               |> Ash.create(actor: admin_actor)
    end

    test "tenant owners cannot demote platform staff", ctx do
      %{org: org, owner: owner, platform_staff: platform_staff} = ctx
      owner_actor = TestFixtures.build_actor(owner, org, :owner)

      {:ok, staff_membership} = get_membership(platform_staff, org)

      assert {:error, %Ash.Error.Forbidden{}} =
               staff_membership
               |> Ash.Changeset.for_destroy(:remove)
               |> Ash.destroy(actor: owner_actor)
    end

    test "platform admins can manage platform staff", ctx do
      %{org: org, platform_admin: platform_admin, platform_staff: platform_staff} = ctx

      platform_admin_actor =
        TestFixtures.build_actor(platform_admin, org, :owner, is_platform_admin: true)

      {:ok, staff_membership} = get_membership(platform_staff, org)

      assert {:ok, _} =
               staff_membership
               |> Ash.Changeset.for_destroy(:remove)
               |> Ash.destroy(actor: platform_admin_actor)
    end

    test "cross-tenant actors cannot read or change memberships", ctx do
      %{org: org, other_org: other_org, owner: owner, member: member} = ctx

      {:ok, owner_membership} = get_membership(owner, org)

      # Actor from other_org trying to access org's memberships
      other_actor = TestFixtures.build_actor(member, other_org, :owner)

      # Cannot read
      assert {:error, %Ash.Error.Forbidden{}} =
               Membership
               |> Ash.Query.filter(id == ^owner_membership.id)
               |> Ash.read_one(actor: other_actor)

      # Cannot update
      assert {:error, %Ash.Error.Forbidden{}} =
               owner_membership
               |> Ash.Changeset.for_update(:update, %{status: :inactive})
               |> Ash.update(actor: other_actor)
    end
  end

  # Helper to get membership via Repo (bypasses policies)
  defp get_membership(user, organization) do
    membership =
      Membership
      |> Ash.Query.filter(user_id == ^user.id and organization_id == ^organization.id)
      |> Ash.read_one!(authorize?: false)

    {:ok, membership}
  end
end
