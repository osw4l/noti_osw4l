defmodule NotiOsw4lWeb.VideoCallLive do
  use NotiOsw4lWeb, :live_view

  alias NotiOsw4l.Workspaces
  alias NotiOsw4lWeb.Presence

  def mount(%{"id" => workspace_id}, _session, socket) do
    workspace = Workspaces.get_workspace!(workspace_id)
    user_id = socket.assigns.current_user.id

    if Workspaces.user_has_access?(workspace.id, user_id) do
      call_topic = "video_call:#{workspace.id}"

      if connected?(socket) do
        Phoenix.PubSub.subscribe(NotiOsw4l.PubSub, call_topic)

        Presence.track(self(), call_topic, to_string(user_id), %{
          username: socket.assigns.current_user.username,
          user_id: user_id,
          publishing: false
        })
      end

      participants = list_participants(call_topic, user_id)

      {:ok,
       assign(socket,
         workspace: workspace,
         call_topic: call_topic,
         participants: participants,
         publishing: false,
         page_title: "Llamada - #{workspace.name}"
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "No tienes acceso a este espacio")
       |> redirect(to: ~p"/workspaces")}
    end
  end

  def handle_event("start_publishing", _params, socket) do
    user_id = socket.assigns.current_user.id
    publisher_id = "publisher-#{user_id}"

    socket =
      socket
      |> LiveExWebRTC.Publisher.attach(
        id: publisher_id,
        pubsub: NotiOsw4l.PubSub,
        recordings?: false
      )
      |> assign(publishing: true)

    Presence.update(self(), socket.assigns.call_topic, to_string(user_id), fn meta ->
      %{meta | publishing: true}
    end)

    {:noreply, socket}
  end

  def handle_event("stop_publishing", _params, socket) do
    user_id = socket.assigns.current_user.id

    Presence.update(self(), socket.assigns.call_topic, to_string(user_id), fn meta ->
      %{meta | publishing: false}
    end)

    {:noreply, assign(socket, publishing: false)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    user_id = socket.assigns.current_user.id
    participants = list_participants(socket.assigns.call_topic, user_id)
    {:noreply, assign(socket, participants: participants)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  defp list_participants(topic, current_user_id) do
    topic
    |> Presence.list()
    |> Enum.flat_map(fn {user_id_str, %{metas: [meta | _]}} ->
      if String.to_integer(user_id_str) != current_user_id do
        [meta]
      else
        []
      end
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-5xl mx-auto mt-8">
      <div class="flex items-center justify-between mb-6">
        <div>
          <.link
            navigate={~p"/workspaces/#{@workspace.id}"}
            class="text-sm text-zinc-500 hover:text-zinc-700"
          >
            &larr; Volver a {@workspace.name}
          </.link>
          <h1 class="text-2xl font-bold mt-1">Llamada - {@workspace.name}</h1>
        </div>
        <div>
          <.button
            :if={!@publishing}
            phx-click="start_publishing"
            class="bg-green-600 hover:bg-green-700"
          >
            Iniciar Video/Audio
          </.button>
          <.button
            :if={@publishing}
            phx-click="stop_publishing"
            class="bg-red-600 hover:bg-red-700"
          >
            Detener
          </.button>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <%!-- Local stream --%>
        <div :if={@publishing} class="relative rounded-lg overflow-hidden bg-zinc-900 aspect-video">
          <LiveExWebRTC.Publisher.live_render socket={@socket} publisher={@publisher} />
          <div class="absolute bottom-2 left-2 bg-black/60 text-white text-xs px-2 py-1 rounded">
            Tu ({@current_user.username})
          </div>
        </div>

        <%!-- Remote participants --%>
        <div
          :for={participant <- @participants}
          class="relative rounded-lg overflow-hidden bg-zinc-900 aspect-video flex flex-col items-center justify-center"
        >
          <p class="text-zinc-400 text-sm mb-2">{participant.username}</p>
          <.link
            :if={participant.publishing}
            navigate={~p"/workspaces/#{@workspace.id}/call/#{participant.user_id}"}
            class="px-3 py-1 bg-blue-500 text-white rounded text-sm hover:bg-blue-600"
          >
            Ver stream
          </.link>
          <p :if={!participant.publishing} class="text-zinc-500 text-xs">
            No está transmitiendo
          </p>
        </div>
      </div>

      <div
        :if={@participants == [] && !@publishing}
        class="text-center py-16 text-zinc-400"
      >
        <p class="text-lg mb-2">No hay nadie en la llamada</p>
        <p class="text-sm">Haz clic en "Iniciar Video/Audio" para comenzar</p>
      </div>
    </div>
    """
  end
end
