defmodule VoelgoedEvents.Actors.Actor do
  @moduledoc """
  THE SYSTEM ACTOR STRUCT.

  AGENTS:
  1. Do not pass raw %User{} structs to Ash actions if possible.
  2. Use this unified Actor struct to normalize permissions across API, Web, and CLI.
  3. `type` should be :user, :system, or :device.
  """
  defstruct [:id, :type, :roles, :tenant_id, :permissions]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: :user | :system | :device,
          roles: [atom()],
          tenant_id: String.t() | nil,
          permissions: MapSet.t()
        }
end
