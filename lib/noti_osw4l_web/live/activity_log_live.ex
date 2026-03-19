defmodule NotiOsw4lWeb.ActivityLogLive do
  use NotiOsw4lWeb, :live_view

  alias NotiOsw4l.Activity
  alias NotiOsw4l.Workspaces

  def mount(%{"id" => id}, _session, socket) do
    workspace = Workspaces.get_workspace!(id)
    user_id = socket.assigns.current_user.id

    if Workspaces.user_has_access?(workspace.id, user_id) do
      logs = Activity.list_logs(workspace.id)

      {:ok,
       assign(socket,
         workspace: workspace,
         logs: logs,
         page_title: "Actividad - #{workspace.name}"
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "No tienes acceso")
       |> redirect(to: ~p"/workspaces")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <div class="mb-6">
        <.link
          navigate={~p"/workspaces/#{@workspace.id}"}
          class="text-sm text-base-content/50 hover:text-base-content/70"
        >
          &larr; Volver a {@workspace.name}
        </.link>
        <h1 class="text-2xl font-bold mt-1">Registro de Actividad</h1>
      </div>

      <div :if={@logs == []} class="text-center py-12 text-base-content/40">
        No hay actividad registrada aún.
      </div>

      <div class="space-y-2">
        <div :for={log <- @logs} class="flex items-start gap-3 p-3 border-b border-base-300">
          <div class={"w-2 h-2 rounded-full mt-2 #{action_color(log.action)}"} />
          <div class="flex-1">
            <p class="text-sm">
              <span class="font-semibold">{(log.user && log.user.username) || "Sistema"}</span>
              <span class="text-base-content/60">{action_label(log.action)}</span>
              <span class="font-medium">{log.entity_type}</span>
              <span :if={log.metadata["title"]} class="text-base-content/50">
                "{log.metadata["title"]}"
              </span>
            </p>
            <p class="text-xs text-base-content/40 mt-0.5">
              {Calendar.strftime(log.inserted_at, "%d/%m/%Y %H:%M")}
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def handle_info({:new_notification, _notification}, socket) do
    send_update(NotiOsw4lWeb.NotificationBellComponent,
      id: "notification-bell",
      current_user: socket.assigns.current_user
    )

    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp action_color("created"), do: "bg-success"
  defp action_color("deleted"), do: "bg-error"
  defp action_color("completed"), do: "bg-info"
  defp action_color("uncompleted"), do: "bg-warning"
  defp action_color(_), do: "bg-base-content/40"

  defp action_label("created"), do: "creó"
  defp action_label("deleted"), do: "eliminó"
  defp action_label("completed"), do: "completó"
  defp action_label("uncompleted"), do: "descompletó"
  defp action_label(action), do: action
end
