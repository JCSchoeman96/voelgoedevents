defmodule Voelgoedevents.Queues.ObanConfig do
  @moduledoc "Central Oban configuration stub."

  def config do
    [
      repo: Voelgoedevents.ObanRepo,
      plugins: [Oban.Plugins.Pruner],
      queues: [default: 10]
    ]
  end
end
