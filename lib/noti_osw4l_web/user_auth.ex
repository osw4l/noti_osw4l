defmodule NotiOsw4lWeb.UserAuth do
  use NotiOsw4lWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias NotiOsw4l.Accounts

  def log_in_user(conn, user) do
    conn
    |> renew_session()
    |> put_session(:user_id, user.id)
    |> redirect(to: ~p"/workspaces")
  end

  def log_out_user(conn) do
    if live_socket_id = get_session(conn, :live_socket_id) do
      NotiOsw4lWeb.Endpoint.broadcast(live_socket_id, "disconnect", %{})
    end

    conn
    |> renew_session()
    |> redirect(to: ~p"/login")
  end

  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user(user_id)
    assign(conn, :current_user, user)
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      if Phoenix.LiveView.connected?(socket) do
        user = socket.assigns.current_user

        NotiOsw4lWeb.Presence.track(self(), "platform:presence", to_string(user.id), %{
          username: user.username,
          user_id: user.id,
          workspace_id: nil,
          workspace_name: nil,
          joined_at: DateTime.utc_now()
        })
      end

      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/login")}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    socket = mount_current_user(socket, session)

    if socket.assigns.current_user do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/workspaces")}
    else
      {:cont, socket}
    end
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    {:cont, mount_current_user(socket, session)}
  end

  defp mount_current_user(socket, session) do
    Phoenix.Component.assign_new(socket, :current_user, fn ->
      user_id = session["user_id"]
      user_id && Accounts.get_user(user_id)
    end)
  end

  defp renew_session(conn) do
    delete_csrf_token()

    conn
    |> configure_session(renew: true)
    |> clear_session()
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "Debes iniciar sesión para acceder.")
      |> redirect(to: ~p"/login")
      |> halt()
    end
  end
end
