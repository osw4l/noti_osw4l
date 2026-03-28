defmodule NotiOsw4lWeb.WorkspaceListLive do
  use NotiOsw4lWeb, :live_view

  alias NotiOsw4l.Workspaces
  alias NotiOsw4l.Accounts
  alias NotiOsw4lWeb.Presence

  @platform_topic "platform:presence"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(NotiOsw4l.PubSub, @platform_topic)

      Presence.track(self(), @platform_topic, to_string(socket.assigns.current_user.id), %{
        username: socket.assigns.current_user.username,
        user_id: socket.assigns.current_user.id,
        workspace_id: nil,
        workspace_name: nil,
        joined_at: DateTime.utc_now()
      })
    end

    all_users = Accounts.list_users()
    online_ids = online_user_ids()

    {:ok,
     assign(socket,
       page_title: "Mis Espacios",
       show_form: false,
       all_users: all_users,
       online_ids: online_ids,
       online_metas: online_user_metas()
     )}
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

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    {:noreply,
     assign(socket,
       online_ids: online_user_ids(),
       online_metas: online_user_metas()
     )}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp online_user_ids do
    @platform_topic
    |> Presence.list()
    |> Enum.map(fn {user_id_str, _} -> String.to_integer(user_id_str) end)
    |> MapSet.new()
  end

  defp online_user_metas do
    @platform_topic
    |> Presence.list()
    |> Enum.into(%{}, fn {user_id_str, %{metas: [meta | _]}} ->
      {String.to_integer(user_id_str), meta}
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="flex h-[calc(100vh-4rem)]">
      <%!-- Main content --%>
      <div class="flex-1 overflow-y-auto">
        <div class="max-w-3xl mx-auto px-4 py-6">
          <div class="flex items-center justify-between mb-6">
            <h1 class="text-2xl font-bold">Mis Espacios</h1>
            <button
              phx-click="toggle_form"
              class="px-4 py-2 bg-zinc-900 text-white rounded-lg text-sm font-medium hover:bg-zinc-700 transition-colors"
            >
              {if @show_form, do: "Cancelar", else: "+ Nuevo"}
            </button>
          </div>

          <div :if={@show_form} class="mb-6 p-4 bg-zinc-50 rounded-lg border">
            <.form for={@form} phx-change="validate" phx-submit="create" class="space-y-4">
              <.input field={@form[:name]} type="text" label="Nombre" required />
              <.input field={@form[:description]} type="textarea" label="Descripción" />
              <.button type="submit" phx-disable-with="Creando...">Crear Espacio</.button>
            </.form>
          </div>

          <div :if={@workspaces == []} class="text-center py-16 text-zinc-400">
            <p class="text-lg">No tienes espacios de trabajo aún</p>
            <p class="text-sm mt-1">Crea uno para empezar a colaborar</p>
          </div>

          <div class="grid gap-3">
            <.link
              :for={workspace <- @workspaces}
              navigate={~p"/workspaces/#{workspace.id}"}
              class="block p-4 border rounded-lg hover:shadow-md hover:border-zinc-300 transition-all bg-white"
            >
              <div class="flex items-center justify-between">
                <div>
                  <h2 class="font-semibold hover:text-blue-600">{workspace.name}</h2>
                  <p :if={workspace.description} class="text-sm text-zinc-500 mt-0.5">
                    {workspace.description}
                  </p>
                  <p class="text-xs text-zinc-400 mt-1.5">
                    por {workspace.owner.username}
                  </p>
                </div>
                <button
                  :if={workspace.owner_id == @current_user.id}
                  phx-click="delete"
                  phx-value-id={workspace.id}
                  data-confirm="¿Eliminar este espacio?"
                  class="text-red-400 hover:text-red-600 text-xs ml-4"
                >
                  Eliminar
                </button>
              </div>
            </.link>
          </div>
        </div>
      </div>

      <%!-- Users sidebar --%>
      <div class="w-64 border-l border-zinc-200 bg-zinc-50 flex flex-col shrink-0">
        <div class="px-4 py-3 border-b border-zinc-200 bg-white">
          <h3 class="font-semibold text-sm">Usuarios</h3>
          <p class="text-xs text-zinc-400">
            {MapSet.size(@online_ids)} online de {length(@all_users)}
          </p>
        </div>
        <div class="flex-1 overflow-y-auto">
          <%!-- Online users first --%>
          <div :if={MapSet.size(@online_ids) > 0} class="px-3 pt-3">
            <p class="text-[10px] font-semibold text-zinc-400 uppercase tracking-wider mb-2">
              Online — {MapSet.size(@online_ids)}
            </p>
            <div class="space-y-0.5">
              <div
                :for={user <- Enum.filter(@all_users, &MapSet.member?(@online_ids, &1.id))}
                class="flex items-center gap-2 px-2 py-1.5 rounded-md hover:bg-zinc-100 transition-colors"
              >
                <span class="relative flex-shrink-0">
                  <span class="flex h-8 w-8 items-center justify-center rounded-full bg-zinc-200 text-xs font-semibold text-zinc-600">
                    {String.first(user.username) |> String.upcase()}
                  </span>
                  <span class="absolute bottom-0 right-0 w-2.5 h-2.5 bg-green-500 rounded-full border-2 border-zinc-50">
                  </span>
                </span>
                <div class="min-w-0 flex-1">
                  <p class="text-sm font-medium truncate">{user.username}</p>
                  <p
                    :if={@online_metas[user.id] && @online_metas[user.id].workspace_name}
                    class="text-[10px] text-zinc-400 truncate"
                  >
                    en {@online_metas[user.id].workspace_name}
                  </p>
                </div>
              </div>
            </div>
          </div>

          <%!-- Offline users --%>
          <div class="px-3 pt-3 pb-3">
            <p class="text-[10px] font-semibold text-zinc-400 uppercase tracking-wider mb-2">
              Offline — {length(@all_users) - MapSet.size(@online_ids)}
            </p>
            <div class="space-y-0.5">
              <div
                :for={user <- Enum.reject(@all_users, &MapSet.member?(@online_ids, &1.id))}
                class="flex items-center gap-2 px-2 py-1.5 rounded-md"
              >
                <span class="relative flex-shrink-0">
                  <span class="flex h-8 w-8 items-center justify-center rounded-full bg-zinc-100 text-xs font-medium text-zinc-400">
                    {String.first(user.username) |> String.upcase()}
                  </span>
                  <span class="absolute bottom-0 right-0 w-2.5 h-2.5 bg-zinc-300 rounded-full border-2 border-zinc-50">
                  </span>
                </span>
                <p class="text-sm text-zinc-400 truncate">{user.username}</p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
