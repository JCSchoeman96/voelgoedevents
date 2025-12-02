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
      DO $$
      DECLARE
        org_count integer;
        target_org uuid;
        ledgers_missing_org integer;
      BEGIN
        SELECT COUNT(*) INTO ledgers_missing_org FROM financial_ledgers WHERE organization_id IS NULL;

        IF ledgers_missing_org = 0 THEN
          RETURN;
        END IF;

        SELECT COUNT(*) INTO org_count FROM organizations;

        IF org_count = 1 THEN
          SELECT id INTO target_org FROM organizations LIMIT 1;
          UPDATE financial_ledgers
          SET organization_id = target_org
          WHERE organization_id IS NULL;
        ELSE
          RAISE EXCEPTION USING
            MESSAGE = format(
              'Cannot backfill organization_id for financial_ledgers: %s organizations exist and %s ledgers need mapping. Provide an explicit mapping before rerunning.',
              org_count,
              ledgers_missing_org
            );
        END IF;
      END;
      $$;
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
