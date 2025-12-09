defmodule Voelgoedevents.Repo.Migrations.StandardizeDatetimeToUsec do
  @moduledoc """
  Standardize all timestamp columns to use microsecond precision.

  This ensures consistent datetime handling across the codebase by using
  `timestamp(6) without time zone` (microsecond precision) everywhere.
  """

  use Ecto.Migration

  def up do
    # Users table
    alter table(:users) do
      modify :confirmed_at, :utc_datetime_usec
      modify :inserted_at, :utc_datetime_usec
      modify :updated_at, :utc_datetime_usec
    end

    # Memberships table
    alter table(:memberships) do
      modify :invited_at, :utc_datetime_usec
      modify :joined_at, :utc_datetime_usec
      modify :inserted_at, :utc_datetime_usec
      modify :updated_at, :utc_datetime_usec
    end

    # Events table (if exists)
    if table_exists?(:events) do
      alter table(:events) do
        modify :start_at, :utc_datetime_usec
        modify :end_at, :utc_datetime_usec
        modify :inserted_at, :utc_datetime_usec
        modify :updated_at, :utc_datetime_usec
      end
    end

    # Tickets table (if exists)
    if table_exists?(:tickets) do
      alter table(:tickets) do
        modify :scanned_at, :utc_datetime_usec
        modify :inserted_at, :utc_datetime_usec
        modify :updated_at, :utc_datetime_usec
      end
    end

    # Organizations table
    alter table(:organizations) do
      modify :inserted_at, :utc_datetime_usec
      modify :updated_at, :utc_datetime_usec
    end

    # Roles table
    alter table(:roles) do
      modify :inserted_at, :utc_datetime_usec
      modify :updated_at, :utc_datetime_usec
    end

    # Organization settings table
    if table_exists?(:organization_settings) do
      alter table(:organization_settings) do
        modify :inserted_at, :utc_datetime_usec
        modify :updated_at, :utc_datetime_usec
      end
    end

    # Invitations table
    if table_exists?(:invitations) do
      alter table(:invitations) do
        modify :inserted_at, :utc_datetime_usec
        modify :updated_at, :utc_datetime_usec
      end
    end

    # Audit logs table
    if table_exists?(:audit_logs) do
      alter table(:audit_logs) do
        modify :inserted_at, :utc_datetime_usec
        modify :updated_at, :utc_datetime_usec
      end
    end
  end

  def down do
    # Users table
    alter table(:users) do
      modify :confirmed_at, :utc_datetime
      modify :inserted_at, :utc_datetime
      modify :updated_at, :utc_datetime
    end

    # Memberships table
    alter table(:memberships) do
      modify :invited_at, :utc_datetime
      modify :joined_at, :utc_datetime
      modify :inserted_at, :utc_datetime
      modify :updated_at, :utc_datetime
    end

    # Events table (if exists)
    if table_exists?(:events) do
      alter table(:events) do
        modify :start_at, :utc_datetime
        modify :end_at, :utc_datetime
        modify :inserted_at, :utc_datetime
        modify :updated_at, :utc_datetime
      end
    end

    # Tickets table (if exists)
    if table_exists?(:tickets) do
      alter table(:tickets) do
        modify :scanned_at, :utc_datetime
        modify :inserted_at, :utc_datetime
        modify :updated_at, :utc_datetime
      end
    end

    # Organizations table
    alter table(:organizations) do
      modify :inserted_at, :utc_datetime
      modify :updated_at, :utc_datetime
    end

    # Roles table
    alter table(:roles) do
      modify :inserted_at, :utc_datetime
      modify :updated_at, :utc_datetime
    end

    # Organization settings table
    if table_exists?(:organization_settings) do
      alter table(:organization_settings) do
        modify :inserted_at, :utc_datetime
        modify :updated_at, :utc_datetime
      end
    end

    # Invitations table
    if table_exists?(:invitations) do
      alter table(:invitations) do
        modify :inserted_at, :utc_datetime
        modify :updated_at, :utc_datetime
      end
    end

    # Audit logs table
    if table_exists?(:audit_logs) do
      alter table(:audit_logs) do
        modify :inserted_at, :utc_datetime
        modify :updated_at, :utc_datetime
      end
    end
  end

  defp table_exists?(table_name) do
    query = """
    SELECT EXISTS (
      SELECT FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = '#{table_name}'
    );
    """

    %{rows: [[exists]]} = repo().query!(query)
    exists
  end
end
