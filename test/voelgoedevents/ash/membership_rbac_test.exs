defmodule Voelgoedevents.Ash.MembershipRbacTest do
  @moduledoc """
  RBAC tests for Membership resource.

  These tests encode the canonical RBAC matrix expectations:
  - Owner: ✅ can invite, change role, revoke
  - Admin: ✅ can invite, change role, revoke (per RBAC matrix)
  - Staff/Viewer/Scanner_only: ❌ cannot manage memberships
  - Cross-tenant: ❌ cannot access memberships

  These tests encode the canonical RBAC matrix and should pass when policies are correctly implemented.
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

      owner =
        TestFixtures.create_user(
          %{first_name: "Owner"},
          organization: org,
          role: roles.owner
        )

      admin =
        TestFixtures.create_user(
          %{first_name: "Admin"},
          organization: org,
          role: roles.admin
        )

      staff =
        TestFixtures.create_user(
          %{first_name: "Staff"},
          organization: org,
          role: roles.staff
        )

      viewer =
        TestFixtures.create_user(
          %{first_name: "Viewer"},
          organization: org,
          role: roles.viewer
        )

      scanner_only =
        TestFixtures.create_user(
          %{first_name: "ScannerOnly"},
          organization: org,
          role: roles.scanner_only
        )

      member =
        TestFixtures.create_user(
          %{first_name: "Member"},
          organization: other_org,
          role: roles.viewer
        )

      target_member =
        TestFixtures.create_user(
          %{first_name: "TargetMember"},
          organization: org,
          role: roles.viewer
        )

      platform_staff =
        TestFixtures.create_user(
          %{first_name: "PlatformStaff"},
          organization: org,
          role: roles.staff,
          is_platform_staff: true
        )

      platform_admin =
        TestFixtures.create_user(
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
         staff: staff,
         viewer: viewer,
         scanner_only: scanner_only,
         member: member,
         target_member: target_member,
         platform_staff: platform_staff,
         platform_admin: platform_admin
       }}
    end

    test "owner can invite, activate, and remove a member", ctx do
      %{roles: roles, org: org, owner: owner, member: member} = ctx
      owner_actor = TestFixtures.build_actor(owner, org, :owner)

      assert {:ok, invitation} =
               Membership
               |> Ash.Changeset.for_create(:invite, %{
                 user_id: member.id,
                 organization_id: org.id,
                 role_id: roles.viewer.id
               })
               |> Ash.create(actor: owner_actor)

      assert {:ok, activated} =
               invitation
               |> Ash.Changeset.for_update(:update, %{status: :active})
               |> Ash.update(actor: owner_actor)

      result =
        activated
        |> Ash.Changeset.for_destroy(:remove, %{})
        |> Ash.destroy(actor: owner_actor)

      # Ash.destroy returns :ok or {:ok, result} depending on after_action
      assert result == :ok or match?({:ok, _}, result)
    end

    test "admin can invite, change role, and revoke memberships", ctx do
      %{roles: roles, org: org, admin: admin, member: member} = ctx
      admin_actor = TestFixtures.build_actor(admin, org, :admin)

      # Admin can invite
      assert {:ok, invitation} =
               Membership
               |> Ash.Changeset.for_create(:invite, %{
                 user_id: member.id,
                 organization_id: org.id,
                 role_id: roles.viewer.id
               })
               |> Ash.create(actor: admin_actor)

      # Admin can change role
      assert {:ok, updated} =
               invitation
               |> Ash.Changeset.for_update(:update, %{role_id: roles.staff.id})
               |> Ash.update(actor: admin_actor)

      # Admin can revoke
      result =
        updated
        |> Ash.Changeset.for_destroy(:remove, %{})
        |> Ash.destroy(actor: admin_actor)

      # Ash.destroy returns :ok or {:ok, result} depending on after_action
      assert result == :ok or match?({:ok, _}, result)
    end

    test "staff cannot invite, change role, or revoke memberships", ctx do
      %{roles: roles, org: org, staff: staff, target_member: target_member} = ctx
      staff_actor = TestFixtures.build_actor(staff, org, :staff)

      # Staff cannot invite
      assert {:error, %Ash.Error.Forbidden{}} =
               Membership
               |> Ash.Changeset.for_create(:invite, %{
                 user_id: target_member.id,
                 organization_id: org.id,
                 role_id: roles.viewer.id
               })
               |> Ash.create(actor: staff_actor)

      # Staff cannot change role
      {:ok, existing_membership} = get_membership(target_member, org)

      assert {:error, %Ash.Error.Forbidden{}} =
               existing_membership
               |> Ash.Changeset.for_update(:update, %{role_id: roles.staff.id})
               |> Ash.update(actor: staff_actor)

      # Staff cannot revoke
      assert {:error, %Ash.Error.Forbidden{}} =
               existing_membership
               |> Ash.Changeset.for_destroy(:remove, %{})
               |> Ash.destroy(actor: staff_actor)
    end

    test "viewer cannot invite, change role, or revoke memberships", ctx do
      %{roles: roles, org: org, viewer: viewer, target_member: target_member} = ctx
      viewer_actor = TestFixtures.build_actor(viewer, org, :viewer)

      # Viewer cannot invite
      assert {:error, %Ash.Error.Forbidden{}} =
               Membership
               |> Ash.Changeset.for_create(:invite, %{
                 user_id: target_member.id,
                 organization_id: org.id,
                 role_id: roles.viewer.id
               })
               |> Ash.create(actor: viewer_actor)

      # Viewer cannot change role
      {:ok, existing_membership} = get_membership(target_member, org)

      assert {:error, %Ash.Error.Forbidden{}} =
               existing_membership
               |> Ash.Changeset.for_update(:update, %{role_id: roles.staff.id})
               |> Ash.update(actor: viewer_actor)

      # Viewer cannot revoke
      assert {:error, %Ash.Error.Forbidden{}} =
               existing_membership
               |> Ash.Changeset.for_destroy(:remove, %{})
               |> Ash.destroy(actor: viewer_actor)
    end

    test "scanner_only cannot invite, change role, or revoke memberships", ctx do
      %{roles: roles, org: org, scanner_only: scanner_only, target_member: target_member} = ctx
      scanner_actor = TestFixtures.build_actor(scanner_only, org, :scanner_only)

      # Scanner_only cannot invite
      assert {:error, %Ash.Error.Forbidden{}} =
               Membership
               |> Ash.Changeset.for_create(:invite, %{
                 user_id: target_member.id,
                 organization_id: org.id,
                 role_id: roles.viewer.id
               })
               |> Ash.create(actor: scanner_actor)

      # Scanner_only cannot change role
      {:ok, existing_membership} = get_membership(target_member, org)

      assert {:error, %Ash.Error.Forbidden{}} =
               existing_membership
               |> Ash.Changeset.for_update(:update, %{role_id: roles.staff.id})
               |> Ash.update(actor: scanner_actor)

      # Scanner_only cannot revoke
      assert {:error, %Ash.Error.Forbidden{}} =
               existing_membership
               |> Ash.Changeset.for_destroy(:remove, %{})
               |> Ash.destroy(actor: scanner_actor)
    end

    test "tenant owners cannot demote platform staff", ctx do
      %{org: org, owner: owner, platform_staff: platform_staff} = ctx
      owner_actor = TestFixtures.build_actor(owner, org, :owner)

      {:ok, staff_membership} = get_membership(platform_staff, org)

      assert {:error, %Ash.Error.Forbidden{}} =
               staff_membership
               |> Ash.Changeset.for_destroy(:remove, %{})
               |> Ash.destroy(actor: owner_actor)
    end

    test "platform admins can manage platform staff", ctx do
      %{org: org, platform_admin: platform_admin, platform_staff: platform_staff} = ctx

      platform_admin_actor =
        TestFixtures.build_actor(platform_admin, org, :owner, is_platform_admin: true)

      {:ok, staff_membership} = get_membership(platform_staff, org)

      result =
        staff_membership
        |> Ash.Changeset.for_destroy(:remove, %{})
        |> Ash.destroy(actor: platform_admin_actor)

      # Ash.destroy returns :ok or {:ok, result} depending on after_action
      assert result == :ok or match?({:ok, _}, result)
    end

    test "cross-tenant actors cannot read or change memberships", ctx do
      %{roles: roles, org: org, other_org: other_org, owner: owner, member: member} = ctx

      {:ok, owner_membership} = get_membership(owner, org)

      other_actor = TestFixtures.build_actor(member, other_org, :owner)

      # Cross-tenant cannot read (FilterByTenant returns nil, not Forbidden)
      assert {:ok, nil} =
               Membership
               |> Ash.Query.filter(id == ^owner_membership.id)
               |> Ash.read_one(actor: other_actor)

      # Cross-tenant cannot invite
      assert {:error, %Ash.Error.Forbidden{}} =
               Membership
               |> Ash.Changeset.for_create(:invite, %{
                 user_id: member.id,
                 organization_id: org.id,
                 role_id: roles.viewer.id
               })
               |> Ash.create(actor: other_actor)

      # Cross-tenant cannot change role
      assert {:error, %Ash.Error.Forbidden{}} =
               owner_membership
               |> Ash.Changeset.for_update(:update, %{role_id: roles.staff.id})
               |> Ash.update(actor: other_actor)

      # Cross-tenant cannot revoke
      assert {:error, %Ash.Error.Forbidden{}} =
               owner_membership
               |> Ash.Changeset.for_destroy(:remove, %{})
               |> Ash.destroy(actor: other_actor)
    end
  end

  defp get_membership(user, organization) do
    system_actor = TestFixtures.build_system_actor(organization)

    membership =
      Membership
      |> Ash.Query.filter(user_id == ^user.id and organization_id == ^organization.id)
      |> Ash.read_one!(authorize?: false, actor: system_actor)

    {:ok, membership}
  end
end
