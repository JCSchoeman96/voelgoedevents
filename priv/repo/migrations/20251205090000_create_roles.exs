defmodule Voelgoedevents.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def up do
    create table(:roles, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
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

    create unique_index(:roles, [:name])
  end

  def down do
    drop_if_exists index(:roles, [:name])
    drop table(:roles)
  end
end
