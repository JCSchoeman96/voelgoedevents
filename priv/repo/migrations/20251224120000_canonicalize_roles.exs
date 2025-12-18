defmodule Voelgoedevents.Repo.Migrations.CanonicalizeRoles do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE roles
    SET
      display_name = CASE name
        WHEN 'owner' THEN 'Owner'
        WHEN 'admin' THEN 'Admin'
        WHEN 'staff' THEN 'Staff'
        WHEN 'viewer' THEN 'Viewer'
        WHEN 'scanner_only' THEN 'Scanner Only'
        ELSE display_name
      END,
      permissions = CASE name
        WHEN 'owner' THEN ARRAY[
          'manage_tenant_users',
          'manage_events_and_venues',
          'manage_ticketing_and_pricing',
          'manage_financials',
          'manage_devices',
          'view_full_analytics'
        ]::text[]
        WHEN 'admin' THEN ARRAY[
          'manage_tenant_users',
          'manage_events_and_venues',
          'manage_ticketing_and_pricing',
          'view_financials',
          'manage_devices',
          'view_full_analytics'
        ]::text[]
        WHEN 'staff' THEN ARRAY[
          'manage_ticketing_and_pricing',
          'view_orders',
          'view_limited_analytics'
        ]::text[]
        WHEN 'viewer' THEN ARRAY[
          'view_read_only'
        ]::text[]
        WHEN 'scanner_only' THEN ARRAY[
          'perform_scans'
        ]::text[]
        ELSE permissions
      END,
      updated_at = (now() AT TIME ZONE 'utc')
    WHERE name IN ('owner', 'admin', 'staff', 'viewer', 'scanner_only');
    """)
  end

  def down do
    # Irreversible data migration (canonical role backfill)
    :ok
  end
end

