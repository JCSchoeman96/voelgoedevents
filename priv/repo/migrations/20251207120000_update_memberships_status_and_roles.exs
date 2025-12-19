defmodule Voelgoedevents.Repo.Migrations.UpdateMembershipsStatusAndRoles do
  use Ecto.Migration

  def up do
    # Note: Role seeding removed from migrations to prevent business logic drift.
    # Roles are seeded via priv/repo/seeds.exs using Ash, which ensures
    # display_name and permissions are set correctly by the resource change function.

    execute("""
    ALTER TABLE memberships
    ADD COLUMN IF NOT EXISTS role_id uuid,
    ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active',
    ADD COLUMN IF NOT EXISTS invited_at timestamptz,
    ADD COLUMN IF NOT EXISTS joined_at timestamptz
    """)

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'memberships' AND column_name = 'role'
      ) THEN
        UPDATE memberships AS m
        SET role_id = r.id
        FROM roles AS r
        WHERE m.role_id IS NULL AND r.name = m.role;
      END IF;
    END$$;
    """)

    execute("""
    UPDATE memberships AS m
    SET role_id = r.id
    FROM roles AS r
    WHERE m.role_id IS NULL AND r.name = 'staff'
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

    execute("""
    DO $$
    BEGIN
      IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'memberships_role_id_fkey'
      ) THEN
        ALTER TABLE memberships
        ADD CONSTRAINT memberships_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id);
      END IF;
    END$$;
    """)

    execute("ALTER TABLE memberships ALTER COLUMN role_id SET NOT NULL")

    execute("ALTER TABLE memberships DROP COLUMN IF EXISTS role")

    create_if_not_exists unique_index(:memberships, [:user_id, :organization_id])
    create_if_not_exists index(:memberships, [:organization_id])
    create_if_not_exists index(:memberships, [:role_id])
  end

  def down do
    execute("ALTER TABLE memberships ADD COLUMN IF NOT EXISTS role text NOT NULL DEFAULT 'staff'")

    execute("""
    UPDATE memberships AS m
    SET role = r.name
    FROM roles AS r
    WHERE m.role_id = r.id
    """)

    execute("ALTER TABLE memberships DROP CONSTRAINT IF EXISTS memberships_role_id_fkey")

    drop_if_exists index(:memberships, [:role_id])

    execute("ALTER TABLE memberships ALTER COLUMN role_id DROP NOT NULL")

    execute("""
    ALTER TABLE memberships
    DROP COLUMN IF EXISTS role_id,
    DROP COLUMN IF EXISTS status,
    DROP COLUMN IF EXISTS invited_at,
    DROP COLUMN IF EXISTS joined_at
    """)
  end
end
