defmodule Voelgoedevents.Auth.ConfirmationSender do
  @moduledoc "Sends confirmation instructions for user accounts."

  use AshAuthentication.Sender
  import Swoosh.Email

  alias Voelgoedevents.Mailer

  @impl true
  def send(user, token, _opts) do
    new()
    |> to({full_name(user), to_string(user.email)})
    |> from({"VoelgoedEvents", "no-reply@voelgoedevents.test"})
    |> subject("Confirm your VoelgoedEvents account")
    |> text_body(build_body(token))
    |> Mailer.deliver()
  end

  defp build_body(token) do
    [
      "Welcome to VoelgoedEvents!",
      "",
      "Use the confirmation token below to finish setting up your account:",
      token,
      "",
      "If you did not request this, you can safely ignore this email."
    ]
    |> Enum.join("\n")
  end

  defp full_name(user) do
    [user.first_name, user.last_name]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> user.email
      name -> name
    end
  end
end
