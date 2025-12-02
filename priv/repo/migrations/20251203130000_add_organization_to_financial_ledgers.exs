defmodule Voelgoedevents.Repo.Migrations.AddOrganizationToFinancialLedgers do
  use Ecto.Migration

  def change do
    alter table(:financial_ledgers) do
      add :organization_id,
          references(:organizations,
            column: :id,
            type: :uuid,
            on_delete: :nothing
          ),
          null: false
    end

    create index(:financial_ledgers, [:organization_id])
  end
end
