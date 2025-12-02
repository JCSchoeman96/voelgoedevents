defmodule Voelgoedevents.Repo.Migrations.AddOrganizationToFinancialLedgers do
  use Ecto.Migration

  def up do
    alter table(:financial_ledgers) do
      add :organization_id,
          references(:organizations,
            column: :id,
            type: :uuid,
            on_delete: :nothing
          ),
          null: true
    end

    execute(
      """
      UPDATE financial_ledgers AS fl
      SET organization_id = org.id
      FROM (
        SELECT id
        FROM organizations
        ORDER BY inserted_at ASC
        LIMIT 1
      ) AS org
      WHERE fl.organization_id IS NULL
      """
    )

    execute(
      """
      ALTER TABLE financial_ledgers
      ALTER COLUMN organization_id SET NOT NULL
      """,
      """
      ALTER TABLE financial_ledgers
      ALTER COLUMN organization_id DROP NOT NULL
      """
    )

    create index(:financial_ledgers, [:organization_id])
  end

  def down do
    drop index(:financial_ledgers, [:organization_id])

    alter table(:financial_ledgers) do
      remove :organization_id
    end
  end
end
