defmodule NotiOsw4lWeb.BrowseWorkspacesLive do
  use NotiOsw4lWeb, :live_view

  import Ecto.Query
  alias NotiOsw4l.Repo
  alias NotiOsw4l.Workspaces.{Workspace, Membership}

  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    workspaces = list_other_workspaces(user_id)
    {:ok, assign(socket, workspaces: workspaces, page_title: "Explorar Espacios")}
  end

  def handle_event("request_access", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id
    workspace_id = String.to_integer(id)

    case NotiOsw4l.Workspaces.request_access(workspace_id, user_id) do
      {:ok, _membership} ->
        Phoenix.PubSub.broadcast(
          NotiOsw4l.PubSub,
          "workspace:#{workspace_id}",
          {:access_requested, socket.assigns.current_user.username}
        )

        {:noreply,
         socket
         |> put_flash(:info, "Solicitud de acceso enviada")
         |> assign(workspaces: list_other_workspaces(user_id))}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Ya tienes una solicitud pendiente")}
    end
  end

  def handle_info({:new_notification, _notification}, socket) do
    send_update(NotiOsw4lWeb.NotificationBellComponent,
      id: "notification-bell",
      current_user: socket.assigns.current_user
    )

    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp list_other_workspaces(user_id) do
    # IDs of workspaces the user already belongs to or owns
    member_workspace_ids =
      from(m in Membership,
        where: m.user_id == ^user_id and m.status in ["accepted", "pending"],
        select: m.workspace_id
      )
      |> Repo.all()

    from(w in Workspace,
      where: w.owner_id != ^user_id and w.id not in ^member_workspace_ids,
      order_by: [desc: w.inserted_at],
      preload: [:owner]
    )
    |> Repo.all()
    |> Enum.map(fn w ->
      member_count =
        from(m in Membership,
          where: m.workspace_id == ^w.id and m.status == "accepted",
          select: count()
        )
        |> Repo.one()

      %{workspace: w, member_count: member_count}
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <h1 class="text-2xl font-bold mb-6">Explorar Espacios de Trabajo</h1>

      <div :if={@workspaces == []} class="text-center py-16 text-base-content/40">
        <p class="text-lg">No hay espacios disponibles</p>
        <p class="text-sm mt-1">Ya eres miembro de todos los espacios existentes</p>
      </div>

      <div class="grid gap-4">
        <div
          :for={%{workspace: w, member_count: count} <- @workspaces}
          class="p-4 border border-base-300 rounded-lg bg-base-100"
        >
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold">{w.name}</h2>
              <p :if={w.description} class="text-sm text-base-content/50">{w.description}</p>
              <p class="text-xs text-base-content/40 mt-1">
                por {w.owner.username} &middot; {count} miembros
              </p>
            </div>
            <button
              phx-click="request_access"
              phx-value-id={w.id}
              class="px-3 py-1.5 bg-primary text-primary-content rounded text-sm hover:brightness-110"
            >
              Solicitar Acceso
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
