# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Voelgoedevents.Repo.insert!(%Voelgoedevents.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Ash.Query
alias Voelgoedevents.Ash.Resources.Accounts.{Membership, Organization, Role, User}
alias Bcrypt

system_actor = %{role: :system}
platform_actor = %{role: :system, is_platform_admin: true}

roles = [
  %{
    name: :owner,
    display_name: "Owner",
    permissions: [
      :manage_organization,
      :manage_users,
      :manage_events,
      :manage_payments,
      :manage_integrations,
      :view_reports
    ]
  },
  %{
    name: :admin,
    display_name: "Admin",
    permissions: [
      :manage_organization,
      :manage_users,
      :manage_events,
      :manage_payments,
      :view_reports
    ]
  },
  %{
    name: :manager,
    display_name: "Manager",
    permissions: [
      :manage_events,
      :manage_ticketing,
      :manage_scanning,
      :manage_support,
      :view_reports
    ]
  },
  %{
    name: :support,
    display_name: "Support",
    permissions: [
      :manage_support,
      :manage_scanning,
      :view_reports
    ]
  },
  %{
    name: :read_only,
    display_name: "Read-only",
    permissions: [
      :view_events,
      :view_reports
    ]
  }
]

Enum.each(roles, fn attrs ->
  Ash.create!(Role, :create, attrs,
    actor: system_actor,
    upsert?: true,
    upsert_keys: [:name],
    upsert_fields: [:display_name, :permissions]
  )
end)

platform_admin_email =
  System.get_env("PLATFORM_ADMIN_EMAIL") ||
    "platform.admin@voelgoedevents.test"

platform_admin_password =
  System.get_env("PLATFORM_ADMIN_PASSWORD") ||
    raise "Set PLATFORM_ADMIN_PASSWORD to a strong, one-time value before seeding"

# Platform admin seed details:
# - Uses PLATFORM_ADMIN_EMAIL (default: platform.admin@voelgoedevents.test).
# - Requires PLATFORM_ADMIN_PASSWORD env var; nothing is printed to avoid leaking secrets.
# - Grants owner membership in the platform ops org; rotate the password or trigger your
#   invite/reset flow after first sign-in.

platform_org_attrs = %{name: "Platform Operations", slug: "platform-operations", status: :active}

platform_org =
  Ash.create!(Organization, :create, platform_org_attrs,
    actor: platform_actor,
    upsert?: true,
    upsert_keys: [:slug],
    upsert_fields: [:name, :status, :settings]
  )

owner_role =
  Role
  |> Query.filter(name == :owner)
  |> Ash.read!(actor: platform_actor)
  |> List.first()

if is_nil(owner_role) do
  raise "Owner role must exist before creating the platform admin user"
end

hashed_password = Bcrypt.hash_pwd_salt(platform_admin_password)

platform_admin_attrs = %{
  email: platform_admin_email,
  first_name: "Platform",
  last_name: "Admin",
  status: :active,
  hashed_password: hashed_password,
  confirmed_at: DateTime.utc_now(),
  organization_id: platform_org.id,
  role_id: owner_role.id,
  is_platform_admin: true
}

platform_admin =
  Ash.create!(User, :create, platform_admin_attrs,
    actor: platform_actor,
    upsert?: true,
    upsert_keys: [:email],
    upsert_fields: [
      :first_name,
      :last_name,
      :status,
      :hashed_password,
      :confirmed_at,
      :is_platform_admin
    ]
  )

Ash.create!(Membership, :create, %{
  user_id: platform_admin.id,
  organization_id: platform_org.id,
  role_id: owner_role.id,
  status: :active,
  joined_at: DateTime.utc_now()
},
  actor: platform_actor,
  upsert?: true,
  upsert_keys: [:user_id, :organization_id],
  upsert_fields: [:role_id, :status, :invited_at, :joined_at]
)

IO.puts("Platform admin seeded for #{platform_org.slug} (#{platform_admin_email})")
