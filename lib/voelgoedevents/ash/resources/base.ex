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
    # 1. Merge Extensions (Auditable + whatever is passed in)
    extension_list = [Voelgoedevents.Ash.Extensions.Auditable | Keyword.get(opts, :extensions, [])]

    # 2. Merge Authorizers (Policy.Authorizer + whatever is passed in)
    authorizer_list = [Ash.Policy.Authorizer | Keyword.get(opts, :authorizers, [])] |> Enum.uniq()

    # 3. Construct Final Options for Ash.Resource
    final_opts =
      opts
      |> Keyword.put(:data_layer, AshPostgres.DataLayer)
      |> Keyword.put(:extensions, extension_list)
      |> Keyword.put(:authorizers, authorizer_list)

    quote do
      use Ash.Resource, unquote(final_opts)

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