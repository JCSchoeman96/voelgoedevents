defmodule Voelgoedevents.Ash.Extensions.Auditable do
  @moduledoc """
  Ash Extension for automatic audit logging.

  Injects after_action hooks on create/update/destroy actions to log changes to AuditLog.

  ## Configuration

  ```elixir
  auditable do
    enabled? true
    strategy :full_diff
    excluded_fields [:password_hash, :updated_at]
    async false  # Synchronous by default (strict compliance)
  end
  ```

  ## Options

  - `:enabled?` - Enable/disable audit logging (default: `true`)
  - `:strategy` - `:full_diff` logs all changed fields, `:minimal` logs only that a change occurred (default: `:full_diff`)
  - `:excluded_fields` - List of field names to exclude from audit diffs (default: `[:updated_at, :created_at, :inserted_at]`)
  - `:async` - Use async audit logging via `spawn/1` (default: `false` for strict compliance)

  ## Behavior

  - **Synchronous (default)**: Audit failures cause transaction rollback
  - **Asynchronous**: Audit failures are logged but don't block the main transaction
  """

  use Spark.Dsl.Extension,
    sections: [@auditable_section],
    transformers: [Voelgoedevents.Ash.Extensions.Auditable.Transformer]

  @auditable_section %Spark.Dsl.Section{
    name: :auditable,
    describe: "Automatic audit logging configuration",
    schema: [
      enabled?: [
        type: :boolean,
        default: true,
        doc: "Enable audit logging for this resource"
      ],
      strategy: [
        type: {:in, [:full_diff, :minimal]},
        default: :full_diff,
        doc: "Log all changed fields (:full_diff) or just that a change occurred (:minimal)"
      ],
      excluded_fields: [
        type: {:list, :atom},
        default: [:updated_at, :created_at, :inserted_at],
        doc: "Fields to exclude from audit change diffs"
      ],
      async: [
        type: :boolean,
        default: false,
        doc: "Use async audit logging (non-blocking, no transaction rollback on audit failure)"
      ]
    ]
  }
end
