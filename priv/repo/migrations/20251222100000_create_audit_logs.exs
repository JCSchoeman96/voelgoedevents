defmodule Voelgoedevents.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def up do
    create table(:audit_logs, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :actor_id, :uuid, null: false
      add :action, :text, null: false
      add :resource, :text, null: false
      add :resource_id, :text, null: false
      add :changes, :map, null: false

      add :organization_id,
          references(:organizations,
            column: :id,
            name: "audit_logs_organization_id_fkey",
            type: :uuid,
            prefix: "public"
          )

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:audit_logs, [:organization_id, :inserted_at])
    create index(:audit_logs, [:resource, :resource_id])
  end

  def down do
    drop_if_exists(index(:audit_logs, [:resource, :resource_id]))
    drop_if_exists(index(:audit_logs, [:organization_id, :inserted_at]))
    drop constraint(:audit_logs, "audit_logs_organization_id_fkey")
    drop table(:audit_logs)
  end
end
