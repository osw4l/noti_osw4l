defmodule NotiOsw4lWeb.VideoPlayerLive do
  use NotiOsw4lWeb, :live_view

  alias NotiOsw4l.Workspaces

  def mount(%{"id" => workspace_id, "publisher_user_id" => publisher_user_id}, _session, socket) do
    workspace = Workspaces.get_workspace!(workspace_id)
    user_id = socket.assigns.current_user.id

    if Workspaces.user_has_access?(workspace.id, user_id) do
      publisher_id = "publisher-#{publisher_user_id}"
      player_id = "player-#{publisher_user_id}-#{user_id}"

      socket =
        socket
        |> LiveExWebRTC.Player.attach(
          id: player_id,
          publisher_id: publisher_id,
          pubsub: NotiOsw4l.PubSub
        )
        |> assign(
          workspace: workspace,
          publisher_user_id: publisher_user_id,
          page_title: "Stream - #{workspace.name}"
        )

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "No tienes acceso a este espacio")
       |> redirect(to: ~p"/workspaces")}
    end
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  def render(assigns) do
    ~H"""
    <div class="max-w-3xl mx-auto mt-8">
      <div class="mb-6">
        <.link
          navigate={~p"/workspaces/#{@workspace.id}/call"}
          class="text-sm text-zinc-500 hover:text-zinc-700"
        >
          &larr; Volver a la llamada
        </.link>
        <h1 class="text-2xl font-bold mt-1">Stream - {@workspace.name}</h1>
      </div>

      <div class="rounded-lg overflow-hidden bg-zinc-900 aspect-video">
        <LiveExWebRTC.Player.live_render socket={@socket} player={@player} />
      </div>
    </div>
    """
  end
end
