defmodule Voelgoedevents.Queues.WorkerCleanupHolds do
  @moduledoc "Oban worker stub for cleaning up seat holds."

  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(_job) do
    # TODO: implement worker logic.
    :ok
  end
end
