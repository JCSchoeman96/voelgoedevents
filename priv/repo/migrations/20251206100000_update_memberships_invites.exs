defmodule Voelgoedevents.Repo.Migrations.UpdateMembershipsInvites do
  use Ecto.Migration

  def up do
    # Idempotent column additions (IF NOT EXISTS)
    execute("""
    ALTER TABLE memberships
    ADD COLUMN IF NOT EXISTS role_id uuid,
    ADD COLUMN IF NOT EXISTS status text,
    ADD COLUMN IF NOT EXISTS invited_at timestamptz,
    ADD COLUMN IF NOT EXISTS joined_at timestamptz
    """)

    # Set defaults after adding columns (idempotent)
    execute("""
    ALTER TABLE memberships
    ALTER COLUMN status SET DEFAULT 'active'
    """)

    execute("""
    UPDATE memberships
    SET status = 'active'
    WHERE status IS NULL
    """)

    # Note: Role seeding removed from migrations to prevent business logic drift.
    # Roles are seeded via priv/repo/seeds.exs using Ash, which ensures
    # display_name and permissions are set correctly by the resource change function.

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
