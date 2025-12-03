defmodule Voelgoedevents.Repo.Migrations.CreateInvitations do
  use Ecto.Migration

  def up do
    create table(:invitations, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :email, :citext, null: false
      add :token, :text, null: false
      add :role, :text, null: false

      add :organization_id,
          references(:organizations,
            column: :id,
            name: "invitations_organization_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:invitations, [:email, :organization_id])
  end

  def down do
    drop_if_exists unique_index(:invitations, [:email, :organization_id])
    drop constraint(:invitations, "invitations_organization_id_fkey")
    drop table(:invitations)
  end
end
