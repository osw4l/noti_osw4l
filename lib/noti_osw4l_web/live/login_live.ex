defmodule NotiOsw4lWeb.LoginLive do
  use NotiOsw4lWeb, :live_view

  def mount(_params, _session, socket) do
    form = to_form(%{"email" => "", "password" => ""}, as: "user")
    {:ok, assign(socket, form: form, check_errors: false, page_title: "Iniciar Sesión")}
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
    <div class="min-h-[calc(100vh-4rem)] flex flex-col items-center justify-center px-4 py-8">
      <%!-- Hero --%>
      <div class="text-center mb-10 max-w-2xl">
        <h1 class="text-4xl font-bold tracking-tight sm:text-5xl">
          noti_osw4l
        </h1>
        <p class="mt-3 text-lg text-base-content/60">
          Espacios de trabajo colaborativos en tiempo real
        </p>
      </div>

      <%!-- Login card --%>
      <div class="w-full max-w-sm bg-base-100 border border-base-300 rounded-xl shadow-lg p-6 mb-12">
        <h2 class="text-xl font-semibold text-center mb-6">Iniciar Sesión</h2>

        <.form
          for={@form}
          action={~p"/login"}
          phx-change="validate"
          phx-submit="save"
          phx-trigger-action={@check_errors}
          class="space-y-4"
        >
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:password]} type="password" label="Contraseña" required />

          <.button type="submit" phx-disable-with="Ingresando..." class="w-full">
            Iniciar Sesión
          </.button>
        </.form>

        <p class="text-center mt-4 text-sm text-base-content/50">
          ¿No tienes cuenta?
          <.link navigate={~p"/register"} class="text-primary hover:underline font-medium">
            Regístrate
          </.link>
        </p>
      </div>

      <%!-- Feature cards --%>
      <div class="w-full max-w-4xl">
        <h3 class="text-center text-sm font-semibold text-base-content/40 uppercase tracking-wider mb-6">
          Funcionalidades
        </h3>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <div class="bg-base-200/50 border border-base-300 rounded-xl p-5">
            <div class="w-10 h-10 rounded-lg bg-blue-500/10 flex items-center justify-center mb-3">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 text-blue-500"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path d="M9 2a1 1 0 000 2h2a1 1 0 100-2H9z" />
                <path
                  fill-rule="evenodd"
                  d="M4 5a2 2 0 012-2 3 3 0 003 3h2a3 3 0 003-3 2 2 0 012 2v11a2 2 0 01-2 2H6a2 2 0 01-2-2V5zm3 4a1 1 0 000 2h.01a1 1 0 100-2H7zm3 0a1 1 0 000 2h3a1 1 0 100-2h-3zm-3 4a1 1 0 100 2h.01a1 1 0 100-2H7zm3 0a1 1 0 100 2h3a1 1 0 100-2h-3z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <h4 class="font-semibold text-sm">Notas y Tareas</h4>
            <p class="text-xs text-base-content/50 mt-1">
              Organiza tu trabajo con notas, listas de tareas y seguimiento de progreso en tiempo real.
            </p>
          </div>

          <div class="bg-base-200/50 border border-base-300 rounded-xl p-5">
            <div class="w-10 h-10 rounded-lg bg-green-500/10 flex items-center justify-center mb-3">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 text-green-500"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path d="M2 3a1 1 0 011-1h2.153a1 1 0 01.986.836l.74 4.435a1 1 0 01-.54 1.06l-1.548.773a11.037 11.037 0 006.105 6.105l.774-1.548a1 1 0 011.059-.54l4.435.74a1 1 0 01.836.986V17a1 1 0 01-1 1h-2C7.82 18 2 12.18 2 5V3z" />
              </svg>
            </div>
            <h4 class="font-semibold text-sm">Canal de Voz</h4>
            <p class="text-xs text-base-content/50 mt-1">
              Comunícate con tu equipo en canales de voz integrados directamente en cada espacio.
            </p>
          </div>

          <div class="bg-base-200/50 border border-base-300 rounded-xl p-5">
            <div class="w-10 h-10 rounded-lg bg-purple-500/10 flex items-center justify-center mb-3">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 text-purple-500"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M18 10c0 3.866-3.582 7-8 7a8.841 8.841 0 01-4.083-.98L2 17l1.338-3.123C2.493 12.767 2 11.434 2 10c0-3.866 3.582-7 8-7s8 3.134 8 7zM7 9H5v2h2V9zm8 0h-2v2h2V9zM9 9h2v2H9V9z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <h4 class="font-semibold text-sm">Chat en Tiempo Real</h4>
            <p class="text-xs text-base-content/50 mt-1">
              Mensajería instantánea dentro de cada espacio de trabajo para mantener la comunicación fluida.
            </p>
          </div>

          <div class="bg-base-200/50 border border-base-300 rounded-xl p-5">
            <div class="w-10 h-10 rounded-lg bg-yellow-500/10 flex items-center justify-center mb-3">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 text-yellow-500"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <h4 class="font-semibold text-sm">Presencia en Tiempo Real</h4>
            <p class="text-xs text-base-content/50 mt-1">
              Ve quién está conectado, sus cursores en pantalla y en qué espacio están trabajando.
            </p>
          </div>

          <div class="bg-base-200/50 border border-base-300 rounded-xl p-5">
            <div class="w-10 h-10 rounded-lg bg-red-500/10 flex items-center justify-center mb-3">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 text-red-500"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path d="M8 9a3 3 0 100-6 3 3 0 000 6zM8 11a6 6 0 016 6H2a6 6 0 016-6zM16 7a1 1 0 10-2 0v1h-1a1 1 0 100 2h1v1a1 1 0 102 0v-1h1a1 1 0 100-2h-1V7z" />
              </svg>
            </div>
            <h4 class="font-semibold text-sm">Invitaciones y Acceso</h4>
            <p class="text-xs text-base-content/50 mt-1">
              Invita miembros, gestiona solicitudes de acceso y controla permisos de tu equipo.
            </p>
          </div>

          <div class="bg-base-200/50 border border-base-300 rounded-xl p-5">
            <div class="w-10 h-10 rounded-lg bg-cyan-500/10 flex items-center justify-center mb-3">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 text-cyan-500"
                viewBox="0 0 20 20"
                fill="currentColor"
              >
                <path
                  fill-rule="evenodd"
                  d="M6 2a1 1 0 00-1 1v1H4a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V6a2 2 0 00-2-2h-1V3a1 1 0 10-2 0v1H7V3a1 1 0 00-1-1zm0 5a1 1 0 000 2h8a1 1 0 100-2H6z"
                  clip-rule="evenodd"
                />
              </svg>
            </div>
            <h4 class="font-semibold text-sm">Registro de Actividad</h4>
            <p class="text-xs text-base-content/50 mt-1">
              Historial completo de todas las acciones realizadas en cada espacio de trabajo.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
