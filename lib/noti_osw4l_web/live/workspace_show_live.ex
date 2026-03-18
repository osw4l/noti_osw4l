defmodule NotiOsw4lWeb.WorkspaceShowLive do
  use NotiOsw4lWeb, :live_view

  alias NotiOsw4l.Workspaces
  alias NotiOsw4l.Notes
  alias NotiOsw4l.Chat
  alias NotiOsw4l.Accounts
  alias NotiOsw4l.Workers.ActivityLogWorker
  alias NotiOsw4lWeb.Presence

  @colors ~w(#ef4444 #f97316 #eab308 #22c55e #06b6d4 #3b82f6 #8b5cf6 #ec4899)
  @platform_topic "platform:presence"

  def mount(%{"id" => id}, _session, socket) do
    workspace = Workspaces.get_workspace!(id)
    user_id = socket.assigns.current_user.id

    if Workspaces.user_has_access?(workspace.id, user_id) do
      workspace_topic = "workspace:#{workspace.id}"
      presence_topic = "workspace_presence:#{workspace.id}"
      call_topic = "video_call:#{workspace.id}"

      if connected?(socket) do
        Phoenix.PubSub.subscribe(NotiOsw4l.PubSub, workspace_topic)
        Phoenix.PubSub.subscribe(NotiOsw4l.PubSub, presence_topic)
        Phoenix.PubSub.subscribe(NotiOsw4l.PubSub, call_topic)
        Phoenix.PubSub.subscribe(NotiOsw4l.PubSub, @platform_topic)

        color = Enum.at(@colors, rem(user_id, length(@colors)))

        Presence.track(self(), presence_topic, to_string(user_id), %{
          username: socket.assigns.current_user.username,
          user_id: user_id,
          color: color,
          cursor_x: nil,
          cursor_y: nil
        })

        # Update platform presence with workspace info
        Presence.update(self(), "platform:presence", to_string(user_id), fn meta ->
          %{meta | workspace_id: workspace.id, workspace_name: workspace.name}
        end)
      end

      members = Workspaces.workspace_members(workspace.id)
      pending = Workspaces.pending_requests(workspace.id)
      is_owner = Workspaces.is_owner?(workspace, user_id)
      notes = Notes.list_notes(workspace.id)
      messages = Chat.list_messages(workspace.id)
      cursors = list_cursors(presence_topic, user_id)
      call_participants = list_call_participants(call_topic, user_id)
      online_ids = platform_online_ids()

      {:ok,
       assign(socket,
         workspace: workspace,
         members: members,
         pending_requests: pending,
         is_owner: is_owner,
         notes: notes,
         messages: messages,
         cursors: cursors,
         presence_topic: presence_topic,
         call_topic: call_topic,
         page_title: workspace.name,
         editing: false,
         show_note_form: false,
         note_form: to_form(Notes.change_note()),
         editing_task: nil,
         task_description: "",
         show_invite: false,
         invite_query: "",
         invite_results: [],
         # Voice state
         in_call: false,
         call_participants: call_participants,
         online_member_ids: online_ids,
         # Right panel: :chat | :voice | nil
         right_panel: nil
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "No tienes acceso a este espacio")
       |> redirect(to: ~p"/workspaces")}
    end
  end

  # ── Right panel ──

  def handle_event("show_panel", %{"panel" => panel}, socket) do
    current = socket.assigns.right_panel
    new_panel = if current == panel, do: nil, else: panel
    {:noreply, assign(socket, right_panel: new_panel)}
  end

  # ── Workspace edit ──

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

  # ── Memberships ──

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

  # ── Notes ──

  def handle_event("toggle_note_form", _params, socket) do
    {:noreply, assign(socket, show_note_form: !socket.assigns.show_note_form)}
  end

  def handle_event("create_note", %{"note" => params}, socket) do
    attrs =
      Map.merge(params, %{
        "workspace_id" => socket.assigns.workspace.id,
        "created_by_id" => socket.assigns.current_user.id
      })

    case Notes.create_note(attrs) do
      {:ok, note} ->
        notes = Notes.list_notes(socket.assigns.workspace.id)
        broadcast_workspace(socket, :notes_updated)
        log_activity(socket, "created", "note", note.id, %{title: note.title})

        {:noreply,
         socket
         |> assign(notes: notes, show_note_form: false, note_form: to_form(Notes.change_note()))
         |> put_flash(:info, "Nota creada")}

      {:error, changeset} ->
        {:noreply, assign(socket, note_form: to_form(changeset))}
    end
  end

  def handle_event("delete_note", %{"id" => id}, socket) do
    note = Notes.get_note!(id)
    Notes.delete_note(note)
    notes = Notes.list_notes(socket.assigns.workspace.id)
    broadcast_workspace(socket, :notes_updated)
    log_activity(socket, "deleted", "note", note.id, %{title: note.title})
    {:noreply, socket |> assign(notes: notes) |> put_flash(:info, "Nota eliminada")}
  end

  # ── Tasks ──

  def handle_event("add_task", %{"note_id" => note_id, "title" => title}, socket) do
    if String.trim(title) != "" do
      attrs = %{
        "title" => title,
        "note_id" => note_id,
        "created_by_id" => socket.assigns.current_user.id
      }

      case Notes.create_task(attrs) do
        {:ok, task} ->
          notes = Notes.list_notes(socket.assigns.workspace.id)
          broadcast_workspace(socket, :notes_updated)
          log_activity(socket, "created", "task", task.id, %{title: title})
          {:noreply, assign(socket, notes: notes)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Error al crear tarea")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_task", %{"id" => id}, socket) do
    user_id = socket.assigns.current_user.id

    case Notes.toggle_task(id, user_id) do
      {:ok, task} ->
        notes = Notes.list_notes(socket.assigns.workspace.id)
        broadcast_workspace(socket, :notes_updated)
        action = if task.completed, do: "completed", else: "uncompleted"
        log_activity(socket, action, "task", task.id, %{title: task.title})
        {:noreply, assign(socket, notes: notes)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al actualizar tarea")}
    end
  end

  def handle_event("edit_task_description", %{"id" => id, "description" => desc}, socket) do
    {:noreply, assign(socket, editing_task: String.to_integer(id), task_description: desc)}
  end

  def handle_event("save_task_description", %{"id" => id}, socket) do
    case Notes.update_task(id, %{"description" => socket.assigns.task_description}) do
      {:ok, _task} ->
        notes = Notes.list_notes(socket.assigns.workspace.id)
        broadcast_workspace(socket, :notes_updated)
        {:noreply, assign(socket, notes: notes, editing_task: nil, task_description: "")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Error al guardar descripción")}
    end
  end

  def handle_event("cancel_edit_description", _params, socket) do
    {:noreply, assign(socket, editing_task: nil, task_description: "")}
  end

  def handle_event("delete_task", %{"id" => id}, socket) do
    Notes.delete_task(id)
    notes = Notes.list_notes(socket.assigns.workspace.id)
    broadcast_workspace(socket, :notes_updated)
    {:noreply, assign(socket, notes: notes)}
  end

  # ── Chat ──

  def handle_event("send_message", %{"body" => body}, socket) do
    if String.trim(body) != "" do
      attrs = %{
        "body" => body,
        "workspace_id" => socket.assigns.workspace.id,
        "user_id" => socket.assigns.current_user.id
      }

      case Chat.create_message(attrs) do
        {:ok, message} ->
          broadcast_workspace(socket, {:new_message, message})
          messages = socket.assigns.messages ++ [message]
          {:noreply, assign(socket, messages: messages)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Error al enviar mensaje")}
      end
    else
      {:noreply, socket}
    end
  end

  # ── Invite ──

  def handle_event("toggle_invite", _params, socket) do
    {:noreply,
     assign(socket,
       show_invite: !socket.assigns.show_invite,
       invite_query: "",
       invite_results: []
     )}
  end

  def handle_event("search_users", %{"query" => query}, socket) do
    results =
      if String.length(query) >= 2 do
        Accounts.search_users(query)
      else
        []
      end

    {:noreply, assign(socket, invite_query: query, invite_results: results)}
  end

  def handle_event("invite_user", %{"user_id" => user_id}, socket) do
    case Workspaces.invite_user(
           socket.assigns.workspace.id,
           String.to_integer(user_id),
           socket.assigns.current_user.id
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitación enviada")
         |> assign(show_invite: false, invite_query: "", invite_results: [])}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "No se pudo invitar (ya tiene acceso o invitación)")}
    end
  end

  # ── Cursors ──

  def handle_event("cursor_move", %{"x" => x, "y" => y}, socket) do
    user_id = socket.assigns.current_user.id
    topic = socket.assigns.presence_topic

    Presence.update(self(), topic, to_string(user_id), fn meta ->
      %{meta | cursor_x: x, cursor_y: y}
    end)

    {:noreply, socket}
  end

  def handle_event("cursor_leave", _params, socket) do
    user_id = socket.assigns.current_user.id
    topic = socket.assigns.presence_topic

    Presence.update(self(), topic, to_string(user_id), fn meta ->
      %{meta | cursor_x: nil, cursor_y: nil}
    end)

    {:noreply, socket}
  end

  # ── Voice/Video (WebRTC) ──

  def handle_event("join_call", _params, socket) do
    user_id = socket.assigns.current_user.id
    username = socket.assigns.current_user.username

    Presence.track(self(), socket.assigns.call_topic, to_string(user_id), %{
      username: username,
      user_id: user_id
    })

    # Notify others in workspace
    Phoenix.PubSub.broadcast(
      NotiOsw4l.PubSub,
      "workspace:#{socket.assigns.workspace.id}",
      {:user_joined_call, username}
    )

    # Tell JS to start WebRTC with existing participants
    existing_peers =
      socket.assigns.call_topic
      |> Presence.list()
      |> Enum.map(fn {uid_str, %{metas: [meta | _]}} ->
        %{user_id: String.to_integer(uid_str), username: meta.username}
      end)
      |> Enum.reject(&(&1.user_id == user_id))

    {:noreply,
     socket
     |> assign(in_call: true)
     |> push_event("webrtc_start", %{user_id: user_id, peers: existing_peers})}
  end

  def handle_event("leave_call", _params, socket) do
    user_id = socket.assigns.current_user.id
    Presence.untrack(self(), socket.assigns.call_topic, to_string(user_id))

    {:noreply,
     socket
     |> assign(in_call: false, call_participants: [])
     |> push_event("webrtc_stop", %{})}
  end

  # ── WebRTC signaling ──

  def handle_event("webrtc_offer", %{"to" => to_id, "offer" => offer}, socket) do
    from_id = socket.assigns.current_user.id
    to_id = if is_binary(to_id), do: String.to_integer(to_id), else: to_id

    Phoenix.PubSub.broadcast(
      NotiOsw4l.PubSub,
      socket.assigns.call_topic,
      {:webrtc_offer, from_id, to_id, offer}
    )

    {:noreply, socket}
  end

  def handle_event("webrtc_answer", %{"to" => to_id, "answer" => answer}, socket) do
    from_id = socket.assigns.current_user.id
    to_id = if is_binary(to_id), do: String.to_integer(to_id), else: to_id

    Phoenix.PubSub.broadcast(
      NotiOsw4l.PubSub,
      socket.assigns.call_topic,
      {:webrtc_answer, from_id, to_id, answer}
    )

    {:noreply, socket}
  end

  def handle_event("webrtc_ice", %{"to" => to_id, "candidate" => candidate}, socket) do
    from_id = socket.assigns.current_user.id
    to_id = if is_binary(to_id), do: String.to_integer(to_id), else: to_id

    Phoenix.PubSub.broadcast(
      NotiOsw4l.PubSub,
      socket.assigns.call_topic,
      {:webrtc_ice, from_id, to_id, candidate}
    )

    {:noreply, socket}
  end

  # ── PubSub handlers ──

  def handle_info(:notes_updated, socket) do
    notes = Notes.list_notes(socket.assigns.workspace.id)
    {:noreply, assign(socket, notes: notes)}
  end

  def handle_info({:new_message, message}, socket) do
    if message.user_id != socket.assigns.current_user.id do
      messages = socket.assigns.messages ++ [message]

      {:noreply,
       socket
       |> assign(messages: messages)
       |> push_event("notify_chat", %{message: "#{message.user.username}: #{message.body}"})}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:user_joined_call, username}, socket) do
    if username != socket.assigns.current_user.username do
      {:noreply,
       socket
       |> push_event("notify_call", %{message: "#{username} se unió al canal de voz"})
       |> put_flash(:info, "#{username} se unió al canal de voz")}
    else
      {:noreply, socket}
    end
  end

  # WebRTC signaling relay
  def handle_info({:webrtc_offer, from_id, to_id, offer}, socket) do
    if to_id == socket.assigns.current_user.id do
      {:noreply, push_event(socket, "webrtc_offer", %{from: from_id, offer: offer})}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:webrtc_answer, from_id, to_id, answer}, socket) do
    if to_id == socket.assigns.current_user.id do
      {:noreply, push_event(socket, "webrtc_answer", %{from: from_id, answer: answer})}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:webrtc_ice, from_id, to_id, candidate}, socket) do
    if to_id == socket.assigns.current_user.id do
      {:noreply, push_event(socket, "webrtc_ice", %{from: from_id, candidate: candidate})}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", topic: topic}, socket) do
    user_id = socket.assigns.current_user.id

    socket =
      cond do
        topic == socket.assigns.presence_topic ->
          cursors = list_cursors(socket.assigns.presence_topic, user_id)
          assign(socket, cursors: cursors)

        topic == socket.assigns.call_topic ->
          participants = list_call_participants(socket.assigns.call_topic, user_id)
          assign(socket, call_participants: participants)

        topic == @platform_topic ->
          assign(socket, online_member_ids: platform_online_ids())

        true ->
          socket
      end

    {:noreply, socket}
  end

  def handle_info({:access_requested, username}, socket) do
    {:noreply, put_flash(socket, :info, "#{username} ha solicitado acceso a este espacio")}
  end

  def handle_info({:new_notification, _notification}, socket) do
    send_update(NotiOsw4lWeb.NotificationBellComponent,
      id: "notification-bell",
      current_user: socket.assigns.current_user
    )

    {:noreply, socket}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

  # ── Helpers ──

  defp broadcast_workspace(socket, event) do
    Phoenix.PubSub.broadcast(
      NotiOsw4l.PubSub,
      "workspace:#{socket.assigns.workspace.id}",
      event
    )
  end

  defp log_activity(socket, action, entity_type, entity_id, metadata) do
    ActivityLogWorker.enqueue(
      action,
      entity_type,
      entity_id,
      socket.assigns.workspace.id,
      socket.assigns.current_user.id,
      metadata
    )
  end

  defp list_cursors(topic, current_user_id) do
    topic
    |> Presence.list()
    |> Enum.flat_map(fn {user_id_str, %{metas: [meta | _]}} ->
      if String.to_integer(user_id_str) != current_user_id && meta.cursor_x do
        [meta]
      else
        []
      end
    end)
  end

  defp platform_online_ids do
    @platform_topic
    |> Presence.list()
    |> Enum.map(fn {user_id_str, _} -> String.to_integer(user_id_str) end)
    |> MapSet.new()
  end

  defp list_call_participants(topic, current_user_id) do
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

  # ── Render ──

  defp all_call_participants(call_topic) do
    call_topic
    |> Presence.list()
    |> Enum.map(fn {uid_str, %{metas: [meta | _]}} ->
      %{user_id: String.to_integer(uid_str), username: meta.username}
    end)
  end

  def render(assigns) do
    assigns = assign(assigns, :all_in_call, all_call_participants(assigns.call_topic))

    ~H"""
    <div class="flex flex-col h-[calc(100vh-4rem)]" id="workspace-area" phx-hook="WebRTCAudio">
      <%!-- Remote cursors --%>
      <div
        :for={cursor <- @cursors}
        class="pointer-events-none fixed z-50 transition-all duration-75 ease-out"
        style={"left: #{cursor.cursor_x}px; top: #{cursor.cursor_y}px"}
      >
        <svg width="16" height="20" viewBox="0 0 16 20" fill={cursor.color}>
          <path d="M0 0L16 12L8 12L4 20L0 0Z" />
        </svg>
        <span
          class="text-xs text-white px-1.5 py-0.5 rounded-full whitespace-nowrap ml-2"
          style={"background-color: #{cursor.color}"}
        >
          {cursor.username}
        </span>
      </div>

      <%!-- Main layout --%>
      <div class="flex flex-1 overflow-hidden">
        <%!-- Main content area --%>
        <div class="flex-1 overflow-y-auto" id="main-scroll" phx-hook="CursorTracker">
          <div class="max-w-3xl mx-auto px-4 py-6">
            <%!-- Header --%>
            <div class="flex items-center justify-between mb-6">
              <div>
                <.link
                  navigate={~p"/workspaces"}
                  class="text-sm text-base-content/50 hover:text-base-content/70"
                >
                  &larr; Volver
                </.link>
                <h1 class="text-2xl font-bold mt-1">{@workspace.name}</h1>
                <p :if={@workspace.description} class="text-base-content/50 text-sm">
                  {@workspace.description}
                </p>
              </div>
              <div class="flex items-center gap-1">
                <.link
                  navigate={~p"/workspaces/#{@workspace.id}/activity"}
                  class="btn btn-ghost btn-sm text-xs"
                >
                  Actividad
                </.link>
                <button
                  phx-click="show_panel"
                  phx-value-panel="chat"
                  class={"p-2 rounded-lg transition-colors " <> if(@right_panel == "chat", do: "bg-info/10 text-info", else: "text-base-content/50 hover:bg-base-200")}
                  title="Chat"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path
                      fill-rule="evenodd"
                      d="M18 10c0 3.866-3.582 7-8 7a8.841 8.841 0 01-4.083-.98L2 17l1.338-3.123C2.493 12.767 2 11.434 2 10c0-3.866 3.582-7 8-7s8 3.134 8 7zM7 9H5v2h2V9zm8 0h-2v2h2V9zM9 9h2v2H9V9z"
                      clip-rule="evenodd"
                    />
                  </svg>
                </button>
                <button
                  :if={@is_owner}
                  phx-click="toggle_invite"
                  class="p-2 rounded-lg text-base-content/50 hover:bg-base-200 transition-colors"
                  title="Invitar"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path d="M8 9a3 3 0 100-6 3 3 0 000 6zM8 11a6 6 0 016 6H2a6 6 0 016-6zM16 7a1 1 0 10-2 0v1h-1a1 1 0 100 2h1v1a1 1 0 102 0v-1h1a1 1 0 100-2h-1V7z" />
                  </svg>
                </button>
                <button
                  :if={@is_owner}
                  phx-click="toggle_edit"
                  class="p-2 rounded-lg text-base-content/50 hover:bg-base-200 transition-colors"
                  title="Editar"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-5 w-5"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path d="M13.586 3.586a2 2 0 112.828 2.828l-.793.793-2.828-2.828.793-.793zM11.379 5.793L3 14.172V17h2.828l8.38-8.379-2.83-2.828z" />
                  </svg>
                </button>
              </div>
            </div>

            <%!-- Edit form --%>
            <div :if={@editing} class="mb-6 p-4 bg-base-200 rounded-lg border border-base-300">
              <.form for={@form} phx-submit="update" class="space-y-4">
                <.input field={@form[:name]} type="text" label="Nombre" required />
                <.input field={@form[:description]} type="textarea" label="Descripción" />
                <.button type="submit">Guardar</.button>
              </.form>
            </div>

            <%!-- Pending Requests --%>
            <div :if={@is_owner && @pending_requests != []} class="mb-6">
              <h2 class="text-sm font-semibold text-base-content/50 uppercase tracking-wide mb-3">
                Solicitudes
              </h2>
              <div class="space-y-2">
                <div
                  :for={req <- @pending_requests}
                  class="alert alert-warning"
                >
                  <span class="font-medium text-sm">{req.user.username}</span>
                  <div class="space-x-2">
                    <button
                      phx-click="accept_membership"
                      phx-value-id={req.id}
                      class="btn btn-success btn-xs"
                    >
                      Aceptar
                    </button>
                    <button
                      phx-click="reject_membership"
                      phx-value-id={req.id}
                      class="btn btn-error btn-xs"
                    >
                      Rechazar
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Members bar --%>
            <div class="mb-6 flex flex-wrap gap-1.5">
              <span
                :for={m <- @members}
                class={"inline-flex items-center px-2.5 py-1 rounded-full text-xs font-medium " <> if(MapSet.member?(@online_member_ids, m.user.id), do: "bg-base-200", else: "bg-base-200/50 text-base-content/40")}
              >
                <span class={"w-2 h-2 rounded-full mr-1.5 " <> if(MapSet.member?(@online_member_ids, m.user.id), do: "bg-green-400", else: "bg-base-content/20")}>
                </span>
                {m.user.username}
                <span class={"ml-1 " <> if(MapSet.member?(@online_member_ids, m.user.id), do: "text-base-content/40", else: "text-base-content/30")}>
                  {m.role}
                </span>
              </span>
            </div>

            <%!-- Voice Call Card --%>
            <div class="mb-6 border border-base-300 rounded-lg bg-base-100 overflow-hidden">
              <div class="flex items-center justify-between px-4 py-3 bg-base-200/50">
                <div class="flex items-center gap-2">
                  <span class={
                    "w-2 h-2 rounded-full " <>
                    if(@all_in_call != [], do: "bg-success animate-pulse", else: "bg-base-content/20")
                  }>
                  </span>
                  <span class="text-sm font-semibold">Canal de Voz</span>
                  <span :if={@all_in_call != []} class="text-xs text-base-content/50">
                    {length(@all_in_call)}
                  </span>
                </div>
                <button
                  :if={!@in_call}
                  phx-click="join_call"
                  class="btn btn-success btn-xs gap-1"
                >
                  <.icon name="hero-phone" class="h-3 w-3" /> Unirse
                </button>
                <button
                  :if={@in_call}
                  phx-click="leave_call"
                  class="btn btn-error btn-xs gap-1"
                >
                  <.icon name="hero-phone-x-mark" class="h-3 w-3" /> Salir
                </button>
              </div>

              <div :if={@all_in_call != []} class="px-4 py-4 border-t border-base-300">
                <div class="flex flex-wrap justify-center gap-6">
                  <div :for={p <- @all_in_call} class="flex flex-col items-center gap-1.5">
                    <div
                      id={"voice-avatar-#{p.user_id}"}
                      class="relative w-16 h-16 rounded-full flex items-center justify-center text-xl font-bold text-white bg-primary transition-shadow duration-150"
                    >
                      <div class="voice-ring absolute inset-0 rounded-full border-3 border-transparent transition-all duration-150">
                      </div>
                      {String.first(p.username) |> String.upcase()}
                      <span class="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 bg-success rounded-full border-2 border-base-100">
                      </span>
                    </div>
                    <span class={"text-xs " <> if(p.user_id == @current_user.id, do: "font-semibold", else: "text-base-content/70")}>
                      {p.username}{if p.user_id == @current_user.id, do: " (tu)", else: ""}
                    </span>
                  </div>
                </div>
              </div>

              <div
                :if={@all_in_call == []}
                class="px-4 py-5 text-center text-sm text-base-content/40 border-t border-base-300"
              >
                Nadie en el canal — unete para hablar
              </div>
            </div>

            <%!-- Notes Section --%>
            <div>
              <div class="flex items-center justify-between mb-4">
                <h2 class="text-sm font-semibold text-base-content/50 uppercase tracking-wide">
                  Notas
                </h2>
                <button
                  phx-click="toggle_note_form"
                  class="text-xs px-3 py-1.5 rounded-lg bg-primary text-primary-content hover:brightness-110 transition-colors"
                >
                  {if @show_note_form, do: "Cancelar", else: "+ Nueva"}
                </button>
              </div>

              <div
                :if={@show_note_form}
                class="mb-4 p-4 bg-base-200 rounded-lg border border-base-300"
              >
                <.form for={@note_form} phx-submit="create_note" class="space-y-3">
                  <.input field={@note_form[:title]} type="text" label="Título" required />
                  <.input field={@note_form[:content]} type="textarea" label="Contenido" />
                  <.button type="submit">Crear</.button>
                </.form>
              </div>

              <div :if={@notes == []} class="text-center py-12 text-base-content/40 text-sm">
                No hay notas aún
              </div>

              <div class="space-y-3">
                <div :for={note <- @notes} class="border border-base-300 rounded-lg p-4 bg-base-100">
                  <div class="flex items-center justify-between mb-3">
                    <div>
                      <h3 class="font-semibold">{note.title}</h3>
                      <p :if={note.content} class="text-sm text-base-content/50 mt-0.5">
                        {note.content}
                      </p>
                      <p :if={note.created_by} class="text-xs text-base-content/40 mt-0.5">
                        por {note.created_by.username}
                      </p>
                    </div>
                    <button
                      phx-click="delete_note"
                      phx-value-id={note.id}
                      data-confirm="¿Eliminar esta nota y todas sus tareas?"
                      class="text-error/60 hover:text-error text-xs"
                    >
                      Eliminar
                    </button>
                  </div>

                  <%!-- Tasks --%>
                  <div class="space-y-1.5">
                    <div :for={task <- note.tasks} class="flex items-start gap-3 group py-1.5">
                      <input
                        type="checkbox"
                        checked={task.completed}
                        phx-click="toggle_task"
                        phx-value-id={task.id}
                        class="checkbox checkbox-success checkbox-sm mt-0.5"
                      />
                      <div class="flex-1 min-w-0">
                        <p class={"text-sm #{if task.completed, do: "line-through text-base-content/40", else: "text-base-content"}"}>
                          {task.title}
                        </p>

                        <div :if={@editing_task == task.id} class="mt-1">
                          <textarea
                            phx-blur="save_task_description"
                            phx-value-id={task.id}
                            phx-keydown="save_task_description"
                            phx-key="Enter"
                            class="w-full text-xs border rounded p-1.5 resize-none"
                            rows="2"
                            phx-hook="TaskDescriptionInput"
                            id={"task-desc-#{task.id}"}
                          >{@task_description}</textarea>
                          <div class="flex gap-2 mt-1">
                            <button
                              phx-click="save_task_description"
                              phx-value-id={task.id}
                              class="text-xs text-blue-600 hover:underline"
                            >
                              Guardar
                            </button>
                            <button
                              phx-click="cancel_edit_description"
                              class="text-xs text-base-content/40 hover:underline"
                            >
                              Cancelar
                            </button>
                          </div>
                        </div>

                        <div :if={@editing_task != task.id}>
                          <p
                            :if={task.description && task.description != ""}
                            class="text-xs text-base-content/50 mt-0.5"
                          >
                            {task.description}
                          </p>
                          <button
                            phx-click="edit_task_description"
                            phx-value-id={task.id}
                            phx-value-description={task.description || ""}
                            class="text-xs text-base-content/30 hover:text-base-content/50 mt-0.5"
                          >
                            {if task.description, do: "editar", else: "+ descripción"}
                          </button>
                        </div>

                        <p
                          :if={task.completed && task.completed_by}
                          class="text-xs text-green-600 mt-0.5"
                        >
                          completada por {task.completed_by.username}
                        </p>
                      </div>
                      <button
                        phx-click="delete_task"
                        phx-value-id={task.id}
                        class="text-error/40 hover:text-error text-xs"
                      >
                        x
                      </button>
                    </div>
                  </div>

                  <form phx-submit="add_task" class="mt-3 flex gap-2">
                    <input type="hidden" name="note_id" value={note.id} />
                    <input
                      type="text"
                      name="title"
                      placeholder="Nueva tarea..."
                      class="input input-bordered input-sm flex-1"
                      autocomplete="off"
                    />
                    <button type="submit" class="btn btn-primary btn-sm">+</button>
                  </form>
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- Right sidebar (chat only) --%>
        <div
          :if={@right_panel == "chat"}
          class="w-80 border-l border-base-300 bg-base-200/50 flex flex-col shrink-0"
        >
          <div class="flex flex-col h-full">
            <div class="px-4 py-3 border-b border-base-300 bg-base-100">
              <h3 class="font-semibold text-sm">Chat</h3>
            </div>
            <div class="flex-1 overflow-y-auto p-3 space-y-2" id="chat-messages" phx-hook="ChatScroll">
              <div :for={msg <- @messages} class="text-sm">
                <span class="font-semibold text-base-content/70">{msg.user.username}</span>
                <span class="text-base-content/50 text-xs ml-1">
                  {Calendar.strftime(msg.inserted_at, "%H:%M")}
                </span>
                <p class="text-base-content/60 text-sm mt-0.5">{msg.body}</p>
              </div>
              <p :if={@messages == []} class="text-center text-base-content/40 text-xs py-8">
                Sin mensajes aún
              </p>
            </div>
            <form phx-submit="send_message" class="border-t border-base-300 p-3 bg-base-100">
              <div class="flex gap-2">
                <input
                  type="text"
                  name="body"
                  placeholder="Escribe un mensaje..."
                  class="input input-bordered input-sm flex-1"
                  autocomplete="off"
                />
                <button type="submit" class="btn btn-info btn-sm btn-square">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4"
                    viewBox="0 0 20 20"
                    fill="currentColor"
                  >
                    <path d="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z" />
                  </svg>
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>

      <%!-- Audio elements for WebRTC --%>
      <div id="webrtc-audio-container" class="hidden"></div>

      <%!-- Invite Modal --%>
      <div :if={@show_invite} class="modal modal-open">
        <div class="modal-box">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-bold">Invitar Usuario</h3>
            <button phx-click="toggle_invite" class="btn btn-ghost btn-sm btn-circle">x</button>
          </div>
          <input
            type="text"
            phx-keyup="search_users"
            phx-value-query={@invite_query}
            value={@invite_query}
            placeholder="Buscar por usuario o email..."
            class="input input-bordered w-full mb-3"
            autocomplete="off"
            name="query"
          />
          <div class="space-y-2 max-h-48 overflow-y-auto">
            <div
              :for={user <- @invite_results}
              class="flex items-center justify-between p-2 hover:bg-base-200 rounded-lg"
            >
              <div>
                <span class="font-medium text-sm">{user.username}</span>
                <span class="text-xs text-base-content/40 ml-2">{user.email}</span>
              </div>
              <button
                phx-click="invite_user"
                phx-value-user_id={user.id}
                class="btn btn-info btn-xs"
              >
                Invitar
              </button>
            </div>
            <p
              :if={@invite_results == [] && String.length(@invite_query) >= 2}
              class="text-sm text-base-content/40 text-center py-2"
            >
              No se encontraron usuarios
            </p>
          </div>
        </div>
        <div class="modal-backdrop" phx-click="toggle_invite"></div>
      </div>
    </div>
    """
  end
end
