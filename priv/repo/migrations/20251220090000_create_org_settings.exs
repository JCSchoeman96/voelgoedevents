defmodule Voelgoedevents.Repo.Migrations.CreateOrgSettings do
  use Ecto.Migration

  def up do
    create table(:organization_settings, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true

      add :organization_id,
          references(:organizations,
            column: :id,
            name: "organization_settings_organization_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :currency, :text, null: false, default: "ZAR"
      add :timezone, :text
      add :primary_color, :text
      add :logo_url, :text

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:organization_settings, [:organization_id])

    execute(
      """
      INSERT INTO organization_settings (id, organization_id, currency, inserted_at, updated_at)
      SELECT gen_random_uuid(), id, 'ZAR', (now() AT TIME ZONE 'utc'), (now() AT TIME ZONE 'utc')
      FROM organizations
      ON CONFLICT (organization_id) DO NOTHING
      """
    )
  end

  def down do
    drop_if_exists(unique_index(:organization_settings, [:organization_id]))
    drop constraint(:organization_settings, "organization_settings_organization_id_fkey")
    drop table(:organization_settings)
  end
end
