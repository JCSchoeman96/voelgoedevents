defmodule Voelgoedevents.Queues.WorkerSendEmail do
  @moduledoc "Oban worker stub for sending emails."

  use Oban.Worker, queue: :default

  @impl Oban.Worker
  def perform(_job) do
    # TODO: implement worker logic.
    :ok
  end
end
