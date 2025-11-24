defmodule Voelgoedevents.Queues.WorkerGeneratePdf do
  @moduledoc "Oban worker stub for generating PDFs."

  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(_job) do
    # TODO: implement worker logic.
    :ok
  end
end
