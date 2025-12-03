defmodule Voelgoedevents.Ash.Validations.PasswordPolicy do
  @moduledoc """
  Ensures passwords satisfy the platform policy.
  """

  use Ash.Resource.Validation

  alias Ash.Changeset

  @blacklist ["password", "123456", "qwerty", "admin", "voelgoed"]
  @error_message "does not meet password requirements"

  @impl true
  def validate(changeset, opts, _context) do
    field = Keyword.get(opts, :field, :password)

    with true <- Changeset.changing_attribute?(changeset, :hashed_password),
         {:ok, password} <- Changeset.fetch_argument(changeset, field),
         true <- valid_password?(password) do
      :ok
    else
      false -> :ok
      :error -> error_response(field)
      {:error, _reason} -> error_response(field)
      _ -> error_response(field)
    end
  end

  defp valid_password?(password) when is_binary(password) do
    String.length(password) >= 10 and
      String.match?(password, ~r/[A-Z]/) and
      String.match?(password, ~r/[a-z]/) and
      String.match?(password, ~r/\d/) and
      not blacklisted?(password)
  end

  defp valid_password?(_), do: false

  defp blacklisted?(password) do
    password
    |> String.downcase()
    |> then(&Enum.member?(@blacklist, &1))
  end

  defp error_response(field) do
    {:error, field: field, message: @error_message}
  end
end
