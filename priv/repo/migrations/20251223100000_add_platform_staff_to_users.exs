defmodule Voelgoedevents.Repo.Migrations.AddPlatformStaffToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_platform_staff, :boolean, null: false, default: false
    end
  end
end
