defmodule NotiOsw4lWeb.RegisterLive do
  use NotiOsw4lWeb, :live_view

  alias NotiOsw4l.Accounts

  def mount(_params, _session, socket) do
    changeset = Accounts.change_user_registration()
    {:ok, assign(socket, form: to_form(changeset), trigger_submit: false)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      Accounts.change_user_registration(%NotiOsw4l.Accounts.User{}, user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Cuenta creada exitosamente. Inicia sesión.")
         |> redirect(to: ~p"/login")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md mt-16">
      <h1 class="text-3xl font-bold text-center mb-8">Crear Cuenta</h1>

      <.form for={@form} phx-change="validate" phx-submit="save" class="space-y-4">
        <div>
          <.input field={@form[:username]} type="text" label="Usuario" required />
        </div>
        <div>
          <.input field={@form[:email]} type="email" label="Email" required />
        </div>
        <div>
          <.input field={@form[:display_name]} type="text" label="Nombre para mostrar" />
        </div>
        <div>
          <.input field={@form[:password]} type="password" label="Contraseña" required />
        </div>

        <.button type="submit" phx-disable-with="Creando..." class="w-full">
          Registrarse
        </.button>
      </.form>

      <p class="text-center mt-4 text-sm text-zinc-500">
        ¿Ya tienes cuenta?
        <.link navigate={~p"/login"} class="text-blue-600 hover:underline">Inicia sesión</.link>
      </p>
    </div>
    """
  end
end
