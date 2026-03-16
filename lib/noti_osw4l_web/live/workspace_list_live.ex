defmodule NotiOsw4lWeb.WorkspaceListLive do
  use NotiOsw4lWeb, :live_view

  alias NotiOsw4l.Workspaces

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Mis Espacios", show_form: false)}
  end

  def handle_params(_params, _uri, socket) do
    workspaces = Workspaces.list_workspaces_for_user(socket.assigns.current_user.id)
    form = to_form(Workspaces.change_workspace())
    {:noreply, assign(socket, workspaces: workspaces, form: form)}
  end

  def handle_event("toggle_form", _params, socket) do
    {:noreply, assign(socket, show_form: !socket.assigns.show_form)}
  end

  def handle_event("validate", %{"workspace" => params}, socket) do
    changeset =
      Workspaces.change_workspace(%NotiOsw4l.Workspaces.Workspace{}, params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("create", %{"workspace" => params}, socket) do
    case Workspaces.create_workspace(params, socket.assigns.current_user.id) do
      {:ok, _workspace} ->
        workspaces = Workspaces.list_workspaces_for_user(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> put_flash(:info, "Espacio creado exitosamente")
         |> assign(
           workspaces: workspaces,
           show_form: false,
           form: to_form(Workspaces.change_workspace())
         )}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Error al crear el espacio")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    workspace = Workspaces.get_workspace!(id)

    if Workspaces.is_owner?(workspace, socket.assigns.current_user.id) do
      Workspaces.delete_workspace(workspace)
      workspaces = Workspaces.list_workspaces_for_user(socket.assigns.current_user.id)

      {:noreply,
       socket |> put_flash(:info, "Espacio eliminado") |> assign(workspaces: workspaces)}
    else
      {:noreply, put_flash(socket, :error, "No tienes permisos")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto mt-8">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">Mis Espacios de Trabajo</h1>
        <.button phx-click="toggle_form">
          {if @show_form, do: "Cancelar", else: "Nuevo Espacio"}
        </.button>
      </div>

      <div :if={@show_form} class="mb-6 p-4 bg-zinc-50 rounded-lg border">
        <.form for={@form} phx-change="validate" phx-submit="create" class="space-y-4">
          <.input field={@form[:name]} type="text" label="Nombre" required />
          <.input field={@form[:description]} type="textarea" label="Descripción" />
          <.button type="submit" phx-disable-with="Creando...">Crear Espacio</.button>
        </.form>
      </div>

      <div :if={@workspaces == []} class="text-center py-12 text-zinc-500">
        <p class="text-lg">No tienes espacios de trabajo aún.</p>
        <p class="text-sm mt-1">Crea uno para empezar a colaborar.</p>
      </div>

      <div class="grid gap-4">
        <div
          :for={workspace <- @workspaces}
          class="p-4 border rounded-lg hover:shadow-md transition-shadow"
        >
          <div class="flex items-center justify-between">
            <.link navigate={~p"/workspaces/#{workspace.id}"} class="flex-1">
              <h2 class="text-lg font-semibold hover:text-blue-600">{workspace.name}</h2>
              <p :if={workspace.description} class="text-sm text-zinc-500 mt-1">
                {workspace.description}
              </p>
              <p class="text-xs text-zinc-400 mt-2">
                Creado por {workspace.owner.username}
              </p>
            </.link>
            <button
              :if={workspace.owner_id == @current_user.id}
              phx-click="delete"
              phx-value-id={workspace.id}
              data-confirm="¿Estás seguro de eliminar este espacio?"
              class="text-red-500 hover:text-red-700 text-sm ml-4"
            >
              Eliminar
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
