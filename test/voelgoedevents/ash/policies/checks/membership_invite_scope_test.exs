defmodule Voelgoedevents.Ash.Policies.Checks.MembershipInviteScopeTest do
  @moduledoc """
  Unit tests for MembershipInviteScope policy check.

  Ensures the check correctly validates actor org matches changeset org
  and enforces owner/admin role requirement.
  """
  use ExUnit.Case, async: true

  alias Ash.Changeset
  alias Voelgoedevents.Ash.Policies.Checks.MembershipInviteScope
  alias Voelgoedevents.Ash.Resources.Accounts.Membership

  describe "match?/3" do
    test "returns true when actor org matches changeset org and role is owner" do
      org_id = Ecto.UUID.generate()
      actor = %{
        user_id: Ecto.UUID.generate(),
        organization_id: org_id,
        role: :owner,
        is_platform_admin: false,
        is_platform_staff: false,
        type: :user
      }

      changeset =
        Membership
        |> Changeset.for_create(:invite, %{
          user_id: Ecto.UUID.generate(),
          organization_id: org_id,
          role_id: Ecto.UUID.generate()
        })

      context = %{changeset: changeset}

      assert MembershipInviteScope.match?(actor, context, []) == true
    end

    test "returns true when actor org matches changeset org and role is admin" do
      org_id = Ecto.UUID.generate()
      actor = %{
        user_id: Ecto.UUID.generate(),
        organization_id: org_id,
        role: :admin,
        is_platform_admin: false,
        is_platform_staff: false,
        type: :user
      }

      changeset =
        Membership
        |> Changeset.for_create(:invite, %{
          user_id: Ecto.UUID.generate(),
          organization_id: org_id,
          role_id: Ecto.UUID.generate()
        })

      context = %{changeset: changeset}

      assert MembershipInviteScope.match?(actor, context, []) == true
    end

    test "returns false when actor org does not match changeset org" do
      actor_org_id = Ecto.UUID.generate()
      target_org_id = Ecto.UUID.generate()

      actor = %{
        user_id: Ecto.UUID.generate(),
        organization_id: actor_org_id,
        role: :owner,
        is_platform_admin: false,
        is_platform_staff: false,
        type: :user
      }

      changeset =
        Membership
        |> Changeset.for_create(:invite, %{
          user_id: Ecto.UUID.generate(),
          organization_id: target_org_id,
          role_id: Ecto.UUID.generate()
        })

      context = %{changeset: changeset}

      assert MembershipInviteScope.match?(actor, context, []) == false
    end

    test "returns false when actor role is staff (not owner/admin)" do
      org_id = Ecto.UUID.generate()
      actor = %{
        user_id: Ecto.UUID.generate(),
        organization_id: org_id,
        role: :staff,
        is_platform_admin: false,
        is_platform_staff: false,
        type: :user
      }

      changeset =
        Membership
        |> Changeset.for_create(:invite, %{
          user_id: Ecto.UUID.generate(),
          organization_id: org_id,
          role_id: Ecto.UUID.generate()
        })

      context = %{changeset: changeset}

      assert MembershipInviteScope.match?(actor, context, []) == false
    end

    test "returns false when actor type is not :user" do
      org_id = Ecto.UUID.generate()
      actor = %{
        user_id: Ecto.UUID.generate(),
        organization_id: org_id,
        role: nil,
        is_platform_admin: false,
        is_platform_staff: false,
        type: :system
      }

      changeset =
        Membership
        |> Changeset.for_create(:invite, %{
          user_id: Ecto.UUID.generate(),
          organization_id: org_id,
          role_id: Ecto.UUID.generate()
        })

      context = %{changeset: changeset}

      assert MembershipInviteScope.match?(actor, context, []) == false
    end

    test "returns false when actor organization_id is nil" do
      org_id = Ecto.UUID.generate()
      actor = %{
        user_id: Ecto.UUID.generate(),
        organization_id: nil,
        role: :owner,
        is_platform_admin: false,
        is_platform_staff: false,
        type: :user
      }

      changeset =
        Membership
        |> Changeset.for_create(:invite, %{
          user_id: Ecto.UUID.generate(),
          organization_id: org_id,
          role_id: Ecto.UUID.generate()
        })

      context = %{changeset: changeset}

      assert MembershipInviteScope.match?(actor, context, []) == false
    end

    test "returns false when context does not have changeset" do
      org_id = Ecto.UUID.generate()
      actor = %{
        user_id: Ecto.UUID.generate(),
        organization_id: org_id,
        role: :owner,
        is_platform_admin: false,
        is_platform_staff: false,
        type: :user
      }

      context = %{}

      assert MembershipInviteScope.match?(actor, context, []) == false
    end
  end
end
