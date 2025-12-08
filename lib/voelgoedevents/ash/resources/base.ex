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

      changes do
        change Voelgoedevents.Ash.Changes.AuditChange
      end

      preparations do
        prepare Voelgoedevents.Ash.Preparations.FilterByTenant
      end
    end
  end
end
