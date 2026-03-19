defmodule NotiOsw4lWeb.NotificationBellComponent do
  use NotiOsw4lWeb, :live_component

  alias NotiOsw4l.Notifications

  def update(assigns, socket) do
    user_id = assigns.current_user.id
    notifications = Notifications.list_unread(user_id)
    count = length(notifications)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(
       notifications: notifications,
       unread_count: count,
       show_dropdown: socket.assigns[:show_dropdown] || false
     )}
  end

  def handle_event("toggle_dropdown", _params, socket) do
    {:noreply, assign(socket, show_dropdown: !socket.assigns.show_dropdown)}
  end

  def handle_event("mark_read", %{"id" => id}, socket) do
    Notifications.mark_as_read(String.to_integer(id), socket.assigns.current_user.id)
    notifications = Notifications.list_unread(socket.assigns.current_user.id)
    {:noreply, assign(socket, notifications: notifications, unread_count: length(notifications))}
  end

  def handle_event("mark_all_read", _params, socket) do
    Notifications.mark_all_as_read(socket.assigns.current_user.id)
    {:noreply, assign(socket, notifications: [], unread_count: 0)}
  end

  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, show_dropdown: false)}
  end

  def render(assigns) do
    ~H"""
    <div class="relative" phx-click-away="close_dropdown" phx-target={@myself}>
      <button
        phx-click="toggle_dropdown"
        phx-target={@myself}
        class="relative p-1.5 rounded-lg hover:bg-white/10 transition-colors"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          class="h-5 w-5"
          viewBox="0 0 20 20"
          fill="currentColor"
        >
          <path d="M10 2a6 6 0 00-6 6v3.586l-.707.707A1 1 0 004 14h12a1 1 0 00.707-1.707L16 11.586V8a6 6 0 00-6-6zM10 18a3 3 0 01-3-3h6a3 3 0 01-3 3z" />
        </svg>
        <span
          :if={@unread_count > 0}
          class="absolute -top-1 -right-1 min-w-[18px] h-[18px] flex items-center justify-center rounded-full bg-error text-error-content text-[10px] font-bold px-1"
        >
          {if @unread_count > 9, do: "9+", else: @unread_count}
        </span>
      </button>

      <div
        :if={@show_dropdown}
        class="absolute right-0 top-full mt-2 w-80 bg-base-100 border border-base-300 rounded-lg shadow-xl z-50 overflow-hidden"
      >
        <div class="flex items-center justify-between px-4 py-3 border-b border-base-300">
          <h3 class="font-semibold text-sm text-base-content">Notificaciones</h3>
          <button
            :if={@unread_count > 0}
            phx-click="mark_all_read"
            phx-target={@myself}
            class="text-xs text-primary hover:underline"
          >
            Marcar todo leido
          </button>
        </div>

        <div class="max-h-80 overflow-y-auto">
          <div
            :for={n <- @notifications}
            class="px-4 py-3 border-b border-base-300/50 hover:bg-base-200/50 transition-colors cursor-pointer"
            phx-click="mark_read"
            phx-target={@myself}
            phx-value-id={n.id}
          >
            <div class="flex items-start gap-3">
              <span class={[
                "mt-0.5 w-8 h-8 rounded-full flex items-center justify-center text-white text-xs shrink-0",
                notification_color(n.type)
              ]}>
                {notification_icon(n.type)}
              </span>
              <div class="min-w-0 flex-1">
                <p class="text-sm font-medium text-base-content">{n.title}</p>
                <p :if={n.body} class="text-xs text-base-content/50 mt-0.5 truncate">{n.body}</p>
                <p class="text-[10px] text-base-content/30 mt-1">{format_time(n.inserted_at)}</p>
              </div>
            </div>
          </div>

          <div :if={@notifications == []} class="px-4 py-8 text-center text-base-content/40 text-sm">
            Sin notificaciones
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp notification_color("invite"), do: "bg-info"
  defp notification_color("access_accepted"), do: "bg-success"
  defp notification_color("access_rejected"), do: "bg-error"
  defp notification_color("access_request"), do: "bg-warning"
  defp notification_color("call"), do: "bg-success"
  defp notification_color("chat"), do: "bg-info"
  defp notification_color(_), do: "bg-neutral"

  defp notification_icon("invite"), do: "+"
  defp notification_icon("access_accepted"), do: "✓"
  defp notification_icon("access_rejected"), do: "✗"
  defp notification_icon("access_request"), do: "?"
  defp notification_icon("call"), do: "☎"
  defp notification_icon("chat"), do: "💬"
  defp notification_icon(_), do: "•"

  defp format_time(dt) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, dt, :second)

    cond do
      diff < 60 -> "ahora"
      diff < 3600 -> "hace #{div(diff, 60)} min"
      diff < 86400 -> "hace #{div(diff, 3600)}h"
      true -> Calendar.strftime(dt, "%d/%m %H:%M")
    end
  end
end
