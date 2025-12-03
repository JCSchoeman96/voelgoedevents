defmodule Voelgoedevents.Repo.Migrations.UpdateMembershipsInvites do
  use Ecto.Migration

  def up do
    alter table(:memberships) do
      add :role_id, references(:roles, type: :uuid, prefix: "public")
      add :status, :text, null: false, default: "active"
      add :invited_at, :utc_datetime_usec
      add :joined_at, :utc_datetime_usec
    end

    execute("""
    INSERT INTO roles (id, name, display_name, permissions, inserted_at, updated_at)
    VALUES
      (gen_random_uuid(), 'owner', 'Owner', '{}', now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc'),
      (gen_random_uuid(), 'admin', 'Admin', '{}', now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc'),
      (gen_random_uuid(), 'manager', 'Manager', '{}', now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc'),
      (gen_random_uuid(), 'support', 'Support', '{}', now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc'),
      (gen_random_uuid(), 'read_only', 'Read-only', '{}', now() AT TIME ZONE 'utc', now() AT TIME ZONE 'utc')
    ON CONFLICT (name) DO NOTHING
    """)

    execute("""
    UPDATE memberships AS m
    SET role_id = r.id
    FROM roles AS r
    WHERE r.name = m.role
    """)

    execute("""
    UPDATE memberships
    SET status = 'active'
    WHERE status IS NULL
    """)

    execute("""
    UPDATE memberships
    SET joined_at = inserted_at
    WHERE joined_at IS NULL
    """)

    execute("ALTER TABLE memberships ALTER COLUMN role_id SET NOT NULL")
    execute("ALTER TABLE memberships DROP COLUMN role")
  end

  def down do
    alter table(:memberships) do
      add :role, :text, null: false, default: "staff"
    end

    execute("""
    UPDATE memberships AS m
    SET role = r.name
    FROM roles AS r
    WHERE r.id = m.role_id
    """)

    alter table(:memberships) do
      remove :role_id
      remove :status
      remove :invited_at
      remove :joined_at
    end
  end
end
