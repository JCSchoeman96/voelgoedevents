defmodule VoelgoedeventsWeb.Auth.ConfirmationLive do
  @moduledoc """
  Confirms a user account using the confirmation token provided in the URL.
  """

  use VoelgoedeventsWeb, :live_view

  alias AshAuthentication.{Info, Strategy}
  alias Voelgoedevents.Ash.Domains.AccountsDomain
  alias Voelgoedevents.Ash.Resources.Accounts.User
  alias VoelgoedeventsWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, status: :pending)}
  end

  @impl true
  def handle_params(%{"token" => token}, _uri, socket) do
    socket = confirm_account(socket, token)

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    socket =
      socket
      |> put_flash(:error, "Confirmation link is invalid or expired.")
      |> assign(status: :error)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-xl py-10">
        <div class="card bg-base-200 shadow-lg border border-base-300">
          <div class="card-body space-y-4">
            <h1 class="text-2xl font-semibold">Account confirmation</h1>

            <p :if={@status == :success} class="text-base-content/80">
              Your account has been successfully confirmed. You can close this page and continue to sign in.
            </p>

            <p :if={@status == :error} class="text-base-content/80">
              The confirmation link is invalid or has already been used. Request a new confirmation email to try again.
            </p>

            <p :if={@status == :pending} class="text-base-content/80">
              Verifying your confirmation link...
            </p>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp confirm_account(socket, token) do
    strategy = Info.strategy!(User, :confirm)

    params = %{to_string(strategy.name) => token}

    case Strategy.action(strategy, :confirm, params, domain: AccountsDomain) do
      {:ok, _user} ->
        socket
        |> put_flash(:info, "Your email has been confirmed.")
        |> assign(status: :success)

      :ok ->
        socket
        |> put_flash(:info, "Your email has been confirmed.")
        |> assign(status: :success)

      {:error, _reason} ->
        socket
        |> put_flash(:error, "Confirmation link is invalid or expired.")
        |> assign(status: :error)
    end
  end
end
