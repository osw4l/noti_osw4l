defmodule NotiOsw4lWeb.WorkspaceShowLive do
  use NotiOsw4lWeb, :live_view

  alias NotiOsw4l.Workspaces

  def mount(%{"id" => id}, _session, socket) do
    workspace = Workspaces.get_workspace!(id)
    user_id = socket.assigns.current_user.id

    if Workspaces.user_has_access?(workspace.id, user_id) do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(NotiOsw4l.PubSub, "workspace:#{workspace.id}")
      end

      members = Workspaces.workspace_members(workspace.id)
      pending = Workspaces.pending_requests(workspace.id)
      is_owner = Workspaces.is_owner?(workspace, user_id)

      {:ok,
       assign(socket,
         workspace: workspace,
         members: members,
         pending_requests: pending,
         is_owner: is_owner,
         page_title: workspace.name,
         editing: false
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "No tienes acceso a este espacio")
       |> redirect(to: ~p"/workspaces")}
    end
  end

  def handle_event("toggle_edit", _params, socket) do
    form = to_form(Workspaces.change_workspace(socket.assigns.workspace))
    {:noreply, assign(socket, editing: !socket.assigns.editing, form: form)}
  end

  def handle_event("update", %{"workspace" => params}, socket) do
    case Workspaces.update_workspace(socket.assigns.workspace, params) do
      {:ok, workspace} ->
        workspace = Workspaces.get_workspace!(workspace.id)

        {:noreply,
         socket
         |> assign(workspace: workspace, editing: false)
         |> put_flash(:info, "Espacio actualizado")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("accept_membership", %{"id" => id}, socket) do
    Workspaces.accept_membership(id)
    pending = Workspaces.pending_requests(socket.assigns.workspace.id)
    members = Workspaces.workspace_members(socket.assigns.workspace.id)
    {:noreply, assign(socket, pending_requests: pending, members: members)}
  end

  def handle_event("reject_membership", %{"id" => id}, socket) do
    Workspaces.reject_membership(id)
    pending = Workspaces.pending_requests(socket.assigns.workspace.id)
    {:noreply, assign(socket, pending_requests: pending)}
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto mt-8">
      <div class="flex items-center justify-between mb-6">
        <div>
          <.link navigate={~p"/workspaces"} class="text-sm text-zinc-500 hover:text-zinc-700">
            &larr; Volver a espacios
          </.link>
          <h1 class="text-2xl font-bold mt-1">{@workspace.name}</h1>
          <p :if={@workspace.description} class="text-zinc-500">{@workspace.description}</p>
        </div>
        <.button :if={@is_owner} phx-click="toggle_edit">
          {if @editing, do: "Cancelar", else: "Editar"}
        </.button>
      </div>

      <div :if={@editing} class="mb-6 p-4 bg-zinc-50 rounded-lg border">
        <.form for={@form} phx-submit="update" class="space-y-4">
          <.input field={@form[:name]} type="text" label="Nombre" required />
          <.input field={@form[:description]} type="textarea" label="Descripción" />
          <.button type="submit">Guardar</.button>
        </.form>
      </div>

      <%!-- Pending Requests --%>
      <div :if={@is_owner && @pending_requests != []} class="mb-6">
        <h2 class="text-lg font-semibold mb-3">Solicitudes pendientes</h2>
        <div class="space-y-2">
          <div
            :for={req <- @pending_requests}
            class="flex items-center justify-between p-3 bg-yellow-50 rounded border border-yellow-200"
          >
            <span class="font-medium">{req.user.username}</span>
            <div class="space-x-2">
              <button
                phx-click="accept_membership"
                phx-value-id={req.id}
                class="px-3 py-1 bg-green-500 text-white rounded text-sm hover:bg-green-600"
              >
                Aceptar
              </button>
              <button
                phx-click="reject_membership"
                phx-value-id={req.id}
                class="px-3 py-1 bg-red-500 text-white rounded text-sm hover:bg-red-600"
              >
                Rechazar
              </button>
            </div>
          </div>
        </div>
      </div>

      <%!-- Members --%>
      <div class="mb-6">
        <h2 class="text-lg font-semibold mb-3">Miembros ({length(@members)})</h2>
        <div class="space-y-2">
          <div :for={m <- @members} class="flex items-center justify-between p-3 bg-zinc-50 rounded">
            <div>
              <span class="font-medium">{m.user.username}</span>
              <span class="ml-2 text-xs px-2 py-0.5 rounded-full bg-zinc-200 text-zinc-600">
                {m.role}
              </span>
            </div>
          </div>
        </div>
      </div>

      <%!-- Notes placeholder --%>
      <div class="border-t pt-6">
        <h2 class="text-lg font-semibold mb-3">Notas</h2>
        <p class="text-zinc-500">Las notas se implementarán en la siguiente branch.</p>
      </div>
    </div>
    """
  end
end
