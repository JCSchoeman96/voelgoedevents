defmodule VoelgoedeventsWeb.PageController do
  use VoelgoedeventsWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
