defmodule NotiOsw4lWeb.OnlineUsersLive do
  use NotiOsw4lWeb, :live_view

  alias NotiOsw4lWeb.Presence

  @platform_topic "platform:presence"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(NotiOsw4l.PubSub, @platform_topic)

      Presence.track(self(), @platform_topic, socket.assigns.current_user.id, %{
        username: socket.assigns.current_user.username,
        user_id: socket.assigns.current_user.id,
        workspace_id: nil,
        workspace_name: nil,
        joined_at: DateTime.utc_now()
      })
    end

    users = list_online_users()
    {:ok, assign(socket, online_users: users, page_title: "Usuarios Online")}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    users = list_online_users()
    {:noreply, assign(socket, online_users: users)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp list_online_users do
    @platform_topic
    |> Presence.list()
    |> Enum.map(fn {_user_id, %{metas: [meta | _]}} -> meta end)
    |> Enum.sort_by(& &1.username)
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto mt-8">
      <h1 class="text-2xl font-bold mb-6">
        Usuarios Online
        <span class="text-sm font-normal text-zinc-400">({length(@online_users)})</span>
      </h1>

      <div class="grid gap-3">
        <div
          :for={user <- @online_users}
          class="flex items-center justify-between p-4 border rounded-lg"
        >
          <div class="flex items-center gap-3">
            <span class="relative flex h-3 w-3">
              <span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-green-400 opacity-75">
              </span>
              <span class="relative inline-flex rounded-full h-3 w-3 bg-green-500"></span>
            </span>
            <span class="font-medium">{user.username}</span>
          </div>
          <div :if={user.workspace_name} class="text-sm text-zinc-500">
            Trabajando en:
            <.link
              navigate={~p"/workspaces/#{user.workspace_id}"}
              class="text-blue-600 hover:underline"
            >
              {user.workspace_name}
            </.link>
          </div>
          <span :if={!user.workspace_name} class="text-sm text-zinc-400">
            Navegando
          </span>
        </div>
      </div>

      <div :if={@online_users == []} class="text-center py-12 text-zinc-400">
        No hay usuarios online en este momento.
      </div>
    </div>
    """
  end
end
