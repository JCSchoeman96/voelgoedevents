# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Seeds canonical RBAC roles using Ash 3.x canonical invocation patterns.
# Only canonical roles are seeded: :owner, :admin, :staff, :viewer, :scanner_only

alias Voelgoedevents.Ash.Resources.Accounts.Role
alias Voelgoedevents.Ash.Support.ActorUtils

# Canonical roles per ASH_3_RBAC_MATRIX.md
# The Role resource's apply_canonical_role_metadata change automatically sets
# display_name and permissions based on the name attribute
canonical_roles = [:owner, :admin, :staff, :viewer, :scanner_only]

# System actor for platform-scoped operations (Role is platform-scoped)
# Per ASH_3_RBAC_MATRIX.md: system actors have role: nil, is_platform_admin: true
# Use stable system actor UUID to prevent identity drift
system_actor = %{
  user_id: ActorUtils.system_actor_user_id(),
  organization_id: nil,  # Platform-scoped resource
  role: nil,
  is_platform_admin: true,
  is_platform_staff: false,
  type: :system
}

Enum.each(canonical_roles, fn role_name ->
  # Check if role exists using Ash 3.x canonical invocation
  # Always use system_actor for reads (even if policy is open) for future-proofing
  require Ash.Query

  existing_role =
    Role
    |> Ash.Query.for_read(:read)
    |> Ash.Query.filter(name == ^role_name)
    |> Ash.read(actor: system_actor)
    |> case do
      {:ok, [role | _]} -> role
      {:ok, []} -> nil
      {:error, reason} ->
        IO.warn("Failed to check role #{role_name}: #{inspect(reason)}")
        nil
    end

  if existing_role do
    # Update existing role to ensure metadata is correct (handles migration-created roles)
    # This ensures display_name and permissions match canonical definitions
    Role
    |> Ash.Changeset.for_update(:update, %{name: role_name})
    |> Ash.update(actor: system_actor)
    |> case do
      {:ok, _role} ->
        IO.puts("Role #{role_name} already exists, metadata updated")

      {:error, reason} ->
        IO.warn("Failed to update role #{role_name}: #{inspect(reason)}")
    end
  else
    # Create role using Ash 3.x canonical invocation
    # Only name is required; display_name and permissions are set by change function
    # Uses system actor with platform admin for authorization
    Role
    |> Ash.Changeset.for_create(:create, %{name: role_name})
    |> Ash.create(actor: system_actor)
    |> case do
      {:ok, _role} ->
        IO.puts("Created role #{role_name}")

      {:error, reason} ->
        IO.warn("Failed to create role #{role_name}: #{inspect(reason)}")
    end
  end
end)
