defmodule Voelgoedevents.Repo.Migrations.CreateUsersAndMemberships do
  use Ecto.Migration

  def up do
    create table(:users, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :email, :citext, null: false
      add :hashed_password, :text, null: false

      add :inserted_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create unique_index(:users, [:email])

    create table(:memberships, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :role, :text, null: false, default: "staff"

      add :user_id,
          references(:users,
            column: :id,
            name: "memberships_user_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false

      add :organization_id,
          references(:organizations,
            column: :id,
            name: "memberships_organization_id_fkey",
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

    create unique_index(:memberships, [:user_id, :organization_id])
    create index(:memberships, [:organization_id])
  end

  def down do
    drop_if_exists index(:memberships, [:organization_id])
    drop_if_exists index(:memberships, [:user_id, :organization_id])
    drop constraint(:memberships, "memberships_organization_id_fkey")
    drop constraint(:memberships, "memberships_user_id_fkey")
    drop table(:memberships)

    drop_if_exists unique_index(:users, [:email])
    drop table(:users)
  end
end
