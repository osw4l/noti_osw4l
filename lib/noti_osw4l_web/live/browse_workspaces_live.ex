defmodule NotiOsw4lWeb.BrowseWorkspacesLive do
  use NotiOsw4lWeb, :live_view

  import Ecto.Query
  alias NotiOsw4l.Repo
  alias NotiOsw4l.Workspaces.{Workspace, Membership}

  def mount(_params, _session, socket) do
    workspaces = list_all_workspaces()
    {:ok, assign(socket, workspaces: workspaces, page_title: "Explorar Espacios")}
  end

  def handle_event("request_access", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case NotiOsw4l.Workspaces.request_access(String.to_integer(id), user_id) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> put_flash(:info, "Solicitud de acceso enviada")
         |> assign(workspaces: list_all_workspaces())}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Ya tienes una solicitud pendiente")}
    end
  end

  defp list_all_workspaces do
    from(w in Workspace,
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
    <div class="max-w-4xl mx-auto mt-8">
      <h1 class="text-2xl font-bold mb-6">Explorar Espacios de Trabajo</h1>

      <div class="grid gap-4">
        <div
          :for={%{workspace: w, member_count: count} <- @workspaces}
          class="p-4 border rounded-lg"
        >
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-lg font-semibold">{w.name}</h2>
              <p :if={w.description} class="text-sm text-zinc-500">{w.description}</p>
              <p class="text-xs text-zinc-400 mt-1">
                por {w.owner.username} &middot; {count} miembros
              </p>
            </div>
            <button
              phx-click="request_access"
              phx-value-id={w.id}
              class="px-3 py-1.5 bg-blue-500 text-white rounded text-sm hover:bg-blue-600"
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
