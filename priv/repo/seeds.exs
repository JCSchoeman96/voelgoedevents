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

roles = [
  %{name: :owner, description: "Organization owner with full control."},
  %{
    name: :admin,
    description: "Tenant administrator with broad management powers (non-financial)."
  },
  %{name: :staff, description: "Operational staff with limited event/scanning capabilities."},
  %{name: :viewer, description: "Read-only user with access to dashboards and reports."},
  %{name: :scanner_only, description: "User restricted to scanning operations only."}
]

Enum.each(roles, fn attrs ->
  params = %{filter: [name: attrs.name]}

  case Ash.read(Role, :read, params, authorize?: false) do
    {:ok, []} ->
      case Ash.create(Role, :create, attrs, authorize?: false) do
        {:ok, _role} -> IO.puts("Created role #{attrs.name}")
        {:error, reason} -> IO.warn("Failed to create role #{attrs.name}: #{inspect(reason)}")
      end

    {:ok, [existing | _]} ->
      if Map.get(existing, :description) != attrs.description do
        case Ash.update(existing, :update, attrs, authorize?: false) do
          {:ok, _role} ->
            IO.puts("Updated description for role #{attrs.name}")

          {:error, reason} ->
            IO.warn("Failed to update role #{attrs.name}: #{inspect(reason)}")
        end
      else
        IO.puts("Role #{attrs.name} already exists, skipping")
      end

    {:error, reason} ->
      IO.warn("Failed to check role #{attrs.name}: #{inspect(reason)}")
  end
end)
