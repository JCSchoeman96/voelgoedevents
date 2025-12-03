defmodule Voelgoedevents.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def up do
    create table(:roles, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :organization_id,
          references(:organizations,
            column: :id,
            name: "roles_organization_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false
      add :name, :text, null: false
      add :display_name, :text, null: false
      add :permissions, {:array, :text}, null: false, default: []

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:roles, [:organization_id])
    create unique_index(:roles, [:organization_id, :name])
  end

  def down do
    drop_if_exists index(:roles, [:organization_id, :name])
    drop_if_exists index(:roles, [:organization_id])
    drop constraint(:roles, "roles_organization_id_fkey")
    drop table(:roles)
  end
end
