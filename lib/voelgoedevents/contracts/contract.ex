defmodule VoelgoedEvents.Contracts.Contract do
  @moduledoc """
  BEHAVIOUR: TYPE-SAFE CONTRACTS

  AGENTS:
  All files in `lib/voelgoedevents/contracts/*` must adopt this behaviour.
  They must define a struct and a `new/1` function that validates input.
  """

  @callback new(map()) :: {:ok, struct()} | {:error, any()}
end
