defmodule Voelgoedevents.Workflows.Ticketing.ReleaseSeat do
  @moduledoc "Workflow: release seat."

  @doc """
  Entry point for this workflow.

  Accepts a map of input data and returns {:ok, result} or {:error, reason}.

  See the matching docs/workflows/*.md file for the detailed behaviour.
  """
  @spec call(map()) :: {:ok, map()} | {:error, term()}
  def call(_input) do
    # TODO: implement workflow orchestration.
    :not_implemented
  end
end
