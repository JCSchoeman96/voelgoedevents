defmodule VoelgoedeventsWeb.AuthHTML do
  @moduledoc """
  HTML views for AuthController.

  Contains templates for authentication-related pages (failure, etc.).
  """
  use VoelgoedeventsWeb, :html

  embed_templates "auth_html/*"
end
