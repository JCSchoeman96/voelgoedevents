defmodule Voelgoedevents.TestFixtures do
  @moduledoc """
  Test fixtures for creating test data via direct Repo insertion.

  These bypass Ash validations and changes to create clean test data
  without triggering complex business logic. Use these for test setup
  when you need predictable, isolated test data.
  """

  alias Voelgoedevents.Repo

  # Standard timestamp with microsecond precision for all tables
  defp now, do: DateTime.utc_now()

  @doc """
  Creates or retrieves all canonical roles.
  Returns a map of role_name => role struct.
  """
  def ensure_roles do
    now = now()

    [:owner, :admin, :staff, :viewer, :scanner_only]
    |> Enum.map(fn name ->
      role =
        case Repo.get_by(Voelgoedevents.Ash.Resources.Accounts.Role, name: name) do
          nil ->
            %Voelgoedevents.Ash.Resources.Accounts.Role{}
            |> Ecto.Changeset.change(%{
              id: Ecto.UUID.generate(),
              name: name,
              display_name: "#{name |> Atom.to_string() |> String.capitalize()} Role",
              permissions: [],
              inserted_at: now,
              updated_at: now
            })
            |> Repo.insert!()

          existing ->
            existing
        end

      {name, role}
    end)
    |> Map.new()
  end

  @doc """
  Creates an organization via direct Repo insert.
  """
  def create_organization(attrs \\ %{}) do
    now = now()

    defaults = %{
      id: Ecto.UUID.generate(),
      name: "Test Org #{System.unique_integer([:positive])}",
      slug: "test-org-#{System.unique_integer([:positive])}",
      status: :active,
      inserted_at: now,
      updated_at: now
    }

    org =
      %Voelgoedevents.Ash.Resources.Accounts.Organization{}
      |> Ecto.Changeset.change(Map.merge(defaults, attrs))
      |> Repo.insert!()

    # Create organization settings
    %Voelgoedevents.Ash.Resources.Organizations.OrganizationSettings{}
    |> Ecto.Changeset.change(%{
      id: Ecto.UUID.generate(),
      organization_id: org.id,
      currency: :ZAR,
      inserted_at: now,
      updated_at: now
    })
    |> Repo.insert!()

    org
  end

  @doc """
  Creates a user via direct Repo insert.

  Options:
    - :organization - the organization (required for membership)
    - :role - the role struct (required for membership)
    - :is_platform_admin - boolean, default false
    - :is_platform_staff - boolean, default false
  """
  def create_user(attrs \\ %{}, opts \\ []) do
    now = now()
    organization = Keyword.get(opts, :organization)
    role = Keyword.get(opts, :role)
    is_platform_admin = Keyword.get(opts, :is_platform_admin, false)
    is_platform_staff = Keyword.get(opts, :is_platform_staff, false)

    defaults = %{
      id: Ecto.UUID.generate(),
      email: "user-#{System.unique_integer([:positive])}@test.example",
      first_name: "Test",
      last_name: "User",
      status: :active,
      hashed_password: Bcrypt.hash_pwd_salt("TestPassword123!"),
      confirmed_at: now,
      is_platform_admin: is_platform_admin,
      is_platform_staff: is_platform_staff,
      inserted_at: now,
      updated_at: now
    }

    user =
      %Voelgoedevents.Ash.Resources.Accounts.User{}
      |> Ecto.Changeset.change(Map.merge(defaults, attrs))
      |> Repo.insert!()

    # Create membership if organization and role provided
    if organization && role do
      create_membership(user, organization, role)
    end

    user
  end

  @doc """
  Creates a membership linking user to organization with role.
  """
  def create_membership(user, organization, role) do
    now = now()

    %Voelgoedevents.Ash.Resources.Accounts.Membership{}
    |> Ecto.Changeset.change(%{
      id: Ecto.UUID.generate(),
      user_id: user.id,
      organization_id: organization.id,
      role_id: role.id,
      status: :active,
      joined_at: now,
      inserted_at: now,
      updated_at: now
    })
    |> Repo.insert!()
  end

  @doc """
  Builds a canonical actor map for use in Ash operations.
  """
  def build_actor(user, organization, role_atom, opts \\ []) do
    %{
      user_id: user.id,
      organization_id: organization.id,
      role: role_atom,
      is_platform_admin: Keyword.get(opts, :is_platform_admin, user.is_platform_admin || false),
      is_platform_staff: Keyword.get(opts, :is_platform_staff, user.is_platform_staff || false),
      type: :user
    }
  end

  @doc """
  Builds a canonical system actor for use in Ash operations.

  System actors are platform-scoped (not tenant-scoped) and do NOT have tenant roles.
  Useful for test helpers that need to read data without authorization checks
  but still satisfy FilterByTenant preparation requirements.

  Options:
    - :is_platform_admin boolean, default true
    - :is_platform_staff boolean, default false
    - :user_id UUID string, optional; defaults to a generated UUID

  Returns a canonical actor map with all 6 required fields:
    - user_id (UUID)
    - organization_id
    - role: nil
    - is_platform_admin
    - is_platform_staff
    - type: :system
  """
  def build_system_actor(organization, opts \\ []) do
    %{
      user_id:
        Keyword.get(opts, :user_id, Voelgoedevents.Ash.Support.ActorUtils.system_actor_user_id()),
      organization_id: organization.id,
      role: nil,
      is_platform_admin: Keyword.get(opts, :is_platform_admin, true),
      is_platform_staff: Keyword.get(opts, :is_platform_staff, false),
      type: :system
    }
  end
end
