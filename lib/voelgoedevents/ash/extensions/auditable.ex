defmodule Voelgoedevents.Ash.Extensions.Auditable do
  @moduledoc """
  Marker extension for resources that participate in audit logging.

  NOTE: The main logic currently lives in Voelgoedevents.Ash.Changes.AuditChange,
  which is injected by Voelgoedevents.Ash.Resources.Base.
  """
  use Spark.Dsl.Extension,
    transformers: [],
    sections: []
end
