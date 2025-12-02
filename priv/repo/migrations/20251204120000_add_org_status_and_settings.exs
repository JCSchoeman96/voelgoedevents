defmodule Voelgoedevents.Repo.Migrations.AddOrgStatusAndSettings do
  @moduledoc """
  Align organizations table with resource by adding status/settings and removing legacy active flag.
  """

  use Ecto.Migration

  def up do
    alter table(:organizations) do
      add :status, :text, null: false, default: "active"
      add :settings, :map, null: false, default: %{}
    end

    execute("""
    UPDATE organizations
    SET status = CASE
      WHEN active IS NULL THEN 'active'
      WHEN active THEN 'active'
      ELSE 'suspended'
    END
    """)

    alter table(:organizations) do
      remove :active
    end
  end

  def down do
    alter table(:organizations) do
      add :active, :boolean, null: false, default: true
    end

    execute("""
    UPDATE organizations
    SET active = CASE status
      WHEN 'active' THEN true
      ELSE false
    END
    """)

    alter table(:organizations) do
      remove :settings
      remove :status
    end
  end
end
