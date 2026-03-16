defmodule NotiOsw4lWeb.PageController do
  use NotiOsw4lWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
