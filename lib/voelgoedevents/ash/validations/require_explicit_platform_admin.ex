defmodule Voelgoedevents.Ash.Validations.RequireExplicitPlatformAdmin do
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    # Check if we are updating, changing the admin status,
    # but haven't provided the explicit argument.
    if changeset.action.type == :update and
         Ash.Changeset.changing_attribute?(changeset, :is_platform_admin) and
         match?(:error, Ash.Changeset.fetch_argument(changeset, :is_platform_admin)) do
      {:error, field: :is_platform_admin, message: "explicit input required"}
    else
      :ok
    end
  end
end
