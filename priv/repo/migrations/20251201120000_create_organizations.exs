defmodule Voelgoedevents.Repo.Migrations.CreateOrganizations do
  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add :status, :text, null: false, default: "active"
      add :settings, :map, null: false, default: %{}
      remove :active
    end

    create unique_index(:organizations, [:slug])
  end

  def down do
    drop_if_exists index(:organizations, [:slug])

    alter table(:organizations) do
      add :active, :boolean, null: false, default: true
      remove :settings
      remove :status
    end
  end
end
