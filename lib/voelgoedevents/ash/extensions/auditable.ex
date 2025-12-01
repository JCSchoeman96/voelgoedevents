defmodule VoelgoedEvents.Ash.Extensions.Auditable do
  @moduledoc """
  EXTENSION: Auditable
  Automatically records who did what.
  """
  use Spark.Dsl.Extension,
    transformers: [],
    sections: []

  # TODO: Logic for hooking into changesets to record actor_id
end
