defmodule Voelgoedevents.Queues.WorkerAnalyticsExport do
  @moduledoc "Oban worker stub for exporting analytics."

  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(_job) do
    # TODO: implement worker logic.
    :ok
  end
end
