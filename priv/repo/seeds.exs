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

alias Voelgoedevents.Ash.Resources.Accounts.Role

system_actor = %{role: :system}

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
