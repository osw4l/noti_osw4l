defmodule NotiOsw4lWeb.PageController do
  use NotiOsw4lWeb, :controller

  def home(conn, _params) do
    if conn.assigns[:current_user] do
      redirect(conn, to: ~p"/workspaces")
    else
      redirect(conn, to: ~p"/login")
    end
  end
end
