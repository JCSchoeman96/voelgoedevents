defmodule VoelgoedeventsWeb.Plugs.SetAshActorPlug do
  @moduledoc """
  Final plug in the authentication chain that constructs the canonical Ash actor.

  ## Single Responsibility

  This plug is THE ONLY place where the Ash actor is constructed.
  It uses `ActorUtils.normalize/1` as the single canonical constructor.

  ## Hydration Pipeline

  1. `CurrentUserPlug` - Loads authenticated user, sets identity assigns
  2. `CurrentOrgPlug` - Determines org + role, validates membership
  3. `SetAshActorPlug` ← YOU ARE HERE - Constructs canonical actor via ActorUtils

  ## Actor Shape (from ActorUtils)

  The actor passed to Ash contains:
  - `:type` - Actor type (:user, :device, :api_key, :system)
  - `:user_id` - User ID (for :user type)
  - `:organization_id` - Active organization ID
  - `:role` - User's role in the organization
  - `:is_platform_admin` - Platform admin flag
  - `:is_platform_staff` - Platform staff flag
  - `:device_id` - Device ID (for :device type, nil for users)
  - `:api_key_id` - API Key ID (for :api_key type, nil for users)
  - `:scopes` - Permission scopes (empty for users)
  - `:device_token` - Device token (nil for users)
  - `:gate_id` - Gate ID (nil for users)

  ## Reads From Assigns

  - `current_user` - The authenticated user (from CurrentUserPlug)
  - `current_organization_id` - Validated org ID (from CurrentOrgPlug)
  - `current_role` - User's role in org (from CurrentOrgPlug)
  - `current_platform_admin?` - Platform admin flag (from CurrentOrgPlug)
  - `current_platform_staff?` - Platform staff flag (from CurrentOrgPlug)

  ## Usage

  Add to router pipeline AFTER CurrentUserPlug and CurrentOrgPlug:

  ```elixir
  pipeline :browser do
    plug :fetch_session
    plug VoelgoedeventsWeb.Plugs.CurrentUserPlug
    plug VoelgoedeventsWeb.Plugs.CurrentOrgPlug
    plug VoelgoedeventsWeb.Plugs.SetAshActorPlug  # ← Constructs canonical actor
  end
  ```
  """

  alias Voelgoedevents.Ash.Support.ActorUtils

  def init(opts), do: opts

  def call(conn, _opts) do
    actor = build_canonical_actor(conn)

    conn
    |> Ash.PlugHelpers.set_actor(actor)
  end

  # Build the canonical actor from conn assigns using ActorUtils
  defp build_canonical_actor(conn) do
    user = conn.assigns[:current_user]

    case user do
      nil ->
        # No authenticated user = no actor
        nil

      %{id: user_id} ->
        # Read all context from assigns (set by CurrentUserPlug and CurrentOrgPlug)
        org_id = conn.assigns[:current_organization_id]
        role = conn.assigns[:current_role]
        is_platform_admin = conn.assigns[:current_platform_admin?] || false
        is_platform_staff = conn.assigns[:current_platform_staff?] || false

        # Build canonical actor input for ActorUtils
        actor_input = %{
          type: :user,
          user_id: user_id,
          organization_id: org_id,
          role: role,
          is_platform_admin: is_platform_admin,
          is_platform_staff: is_platform_staff,
          # User actors don't have device/api_key context
          device_id: nil,
          api_key_id: nil,
          scopes: [],
          device_token: nil,
          gate_id: nil
        }

        # ActorUtils.normalize/1 is the SINGLE canonical constructor
        # It validates shape and either returns {:ok, actor} or {:error, :invalid_actor}
        case ActorUtils.normalize(actor_input) do
          {:ok, actor} ->
            actor

          {:error, :invalid_actor} ->
            raise ArgumentError, "Invalid actor constructed in SetAshActorPlug"
        end
    end
  end
end
