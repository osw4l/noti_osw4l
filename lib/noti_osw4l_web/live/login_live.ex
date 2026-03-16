defmodule NotiOsw4lWeb.LoginLive do
  use NotiOsw4lWeb, :live_view

  def mount(_params, _session, socket) do
    form = to_form(%{"email" => "", "password" => ""}, as: "user")
    {:ok, assign(socket, form: form, check_errors: false)}
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    form = to_form(user_params, as: "user")
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("save", %{"user" => _user_params}, socket) do
    {:noreply, assign(socket, check_errors: true)}
  end

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-md mt-16">
      <h1 class="text-3xl font-bold text-center mb-8">Iniciar Sesión</h1>

      <.form
        for={@form}
        action={~p"/login"}
        phx-change="validate"
        phx-submit="save"
        phx-trigger-action={@check_errors}
        class="space-y-4"
      >
        <div>
          <.input field={@form[:email]} type="email" label="Email" required />
        </div>
        <div>
          <.input field={@form[:password]} type="password" label="Contraseña" required />
        </div>

        <.button type="submit" phx-disable-with="Ingresando..." class="w-full">
          Iniciar Sesión
        </.button>
      </.form>

      <p class="text-center mt-4 text-sm text-zinc-500">
        ¿No tienes cuenta?
        <.link navigate={~p"/register"} class="text-blue-600 hover:underline">Regístrate</.link>
      </p>
    </div>
    """
  end
end
