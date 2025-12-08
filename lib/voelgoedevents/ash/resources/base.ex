defmodule Voelgoedevents.Ash.Resources.Base do
  @moduledoc """
  Base resource for tenant-scoped resources.
  Enforces:
  - AshPostgres data layer
  - Auditable extension
  - Ash.Policy.Authorizer
  - FilterByTenant preparation
  """

  defmacro __using__(opts) do
    extensions = [Voelgoedevents.Ash.Extensions.Auditable | Keyword.get(opts, :extensions, [])]

    # We remove extensions from opts to avoid duplication if we passed it manually,
    # though strict Keyword.merge might be better.
    # But since we are constructing the call to `use Ash.Resource`, we should prepare the arguments.

    # Authorizers: Always include Ash.Policy.Authorizer
    authorizers = [Ash.Policy.Authorizer | Keyword.get(opts, :authorizers, [])] |> Enum.uniq()

    # Data Layer: Default to AshPostgres.DataLayer unless specified (but task says "Base should set data_layer")
    # We will force it or default it. Let's strictly use AshPostgres as requested.
    opts =
      opts
      |> Keyword.put(:data_layer, AshPostgres.DataLayer)
      |> Keyword.put(:extensions, extensions)
      |> Keyword.put(:authorizers, authorizers)

    quote do
      use Ash.Resource, unquote(opts)

      preparations do
        prepare Voelgoedevents.Ash.Preparations.FilterByTenant
      end

      # Auditable extension handles audit hooks via transformer
      auditable do
        enabled? true
        strategy :full_diff
        excluded_fields [:updated_at, :created_at, :inserted_at]
        async false  # Synchronous (strict compliance)
      end
    end
  end
end
