defmodule Voelgoedevents.Repo.Migrations.AddUserFieldsAndTokens do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :first_name, :text, null: false, default: ""
      add :last_name, :text, null: false, default: ""
      add :status, :text, null: false, default: "pending"
      add :confirmed_at, :utc_datetime_usec
    end

    create table(:user_tokens, primary_key: false) do
      add :jti, :text, null: false, primary_key: true
      add :subject, :text, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :purpose, :text, null: false
      add :extra_data, :map

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end

    create index(:user_tokens, [:subject])
  end

  def down do
    drop_if_exists index(:user_tokens, [:subject])
    drop table(:user_tokens)

    alter table(:users) do
      remove :confirmed_at
      remove :status
      remove :last_name
      remove :first_name
    end
  end
end
