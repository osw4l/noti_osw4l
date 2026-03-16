defmodule NotiOsw4lWeb.SessionController do
  use NotiOsw4lWeb, :controller

  alias NotiOsw4l.Accounts
  alias NotiOsw4lWeb.UserAuth

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_session(:live_socket_id, "users_sessions:#{user.id}")
        |> UserAuth.log_in_user(user)

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Email o contraseña incorrectos")
        |> redirect(to: ~p"/login")
    end
  end

  def delete(conn, _params) do
    UserAuth.log_out_user(conn)
  end
end
