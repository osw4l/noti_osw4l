defmodule NotiOsw4lWeb.WorkspaceShowLive do
  use NotiOsw4lWeb, :live_view

  alias NotiOsw4l.Workspaces
  alias NotiOsw4l.Notes
  alias NotiOsw4l.Chat
  alias NotiOsw4l.Accounts
  alias NotiOsw4l.Workers.ActivityLogWorker
  alias NotiOsw4lWeb.Presence

  @colors ~w(#ef4444 #f97316 #eab308 #22c55e #06b6d4 #3b82f6 #8b5cf6 #ec4899)

  def mount(%{"id" => id}, _session, socket) do
    workspace = Workspaces.get_workspace!(id)
    user_id = socket.assigns.current_user.id

    if Workspaces.user_has_access?(workspace.id, user_id) do
      workspace_topic = "workspace:#{workspace.id}"
      presence_topic = "workspace_presence:#{workspace.id}"

      if connected?(socket) do
        Phoenix.PubSub.subscribe(NotiOsw4l.PubSub, workspace_topic)
        Phoenix.PubSub.subscribe(NotiOsw4l.PubSub, presence_topic)

        color = Enum.at(@colors, rem(user_id, length(@colors)))

        Presence.track(self(), presence_topic, to_string(user_id), %{
          username: socket.assigns.current_user.username,
          user_id: user_id,
          color: color,
          cursor_x: nil,
          cursor_y: nil
        })

        # Track on platform presence too
        Presence.track(self(), "platform:presence", to_string(user_id), %{
          username: socket.assigns.current_user.username,
          user_id: user_id,
          workspace_id: workspace.id,
          workspace_name: workspace.name,
          joined_at: DateTime.utc_now()
        })
      end

      members = Workspaces.workspace_members(workspace.id)
      pending = Workspaces.pending_requests(workspace.id)
      is_owner = Workspaces.is_owner?(workspace, user_id)
      notes = Notes.list_notes(workspace.id)
      messages = Chat.list_messages(workspace.id)
      cursors = list_cursors(presence_topic, user_id)

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
         page_title: workspace.name,
         editing: false,
         show_note_form: false,
         note_form: to_form(Notes.change_note()),
         editing_task: nil,
         task_description: "",
         show_chat: false,
         show_invite: false,
         invite_query: "",
         invite_results: []
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

  # Notes
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

  # Tasks
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

  # Chat
  def handle_event("toggle_chat", _params, socket) do
    {:noreply, assign(socket, show_chat: !socket.assigns.show_chat)}
  end

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

  # Invite
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

  # Cursor events
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

  # PubSub
  def handle_info(:notes_updated, socket) do
    notes = Notes.list_notes(socket.assigns.workspace.id)
    {:noreply, assign(socket, notes: notes)}
  end

  def handle_info({:new_message, message}, socket) do
    # Avoid duplicating messages for the sender
    if message.user_id != socket.assigns.current_user.id do
      messages = socket.assigns.messages ++ [message]
      {:noreply, assign(socket, messages: messages)}
    else
      {:noreply, socket}
    end
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    user_id = socket.assigns.current_user.id
    cursors = list_cursors(socket.assigns.presence_topic, user_id)
    {:noreply, assign(socket, cursors: cursors)}
  end

  def handle_info(_msg, socket), do: {:noreply, socket}

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

  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto mt-8 relative" id="workspace-area" phx-hook="CursorTracker">
      <%!-- Remote cursors --%>
      <div
        :for={cursor <- @cursors}
        class="pointer-events-none absolute z-50 transition-all duration-75 ease-out"
        style={"left: #{cursor.cursor_x}%; top: #{cursor.cursor_y}%"}
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

      <%!-- Header --%>
      <div class="flex items-center justify-between mb-6">
        <div>
          <.link navigate={~p"/workspaces"} class="text-sm text-zinc-500 hover:text-zinc-700">
            &larr; Volver a espacios
          </.link>
          <h1 class="text-2xl font-bold mt-1">{@workspace.name}</h1>
          <p :if={@workspace.description} class="text-zinc-500">{@workspace.description}</p>
        </div>
        <div class="flex gap-2">
          <.link navigate={~p"/workspaces/#{@workspace.id}/activity"} class="btn btn-ghost text-sm">
            Actividad
          </.link>
          <.button phx-click="toggle_chat" class="text-sm">
            Chat
          </.button>
          <.button :if={@is_owner} phx-click="toggle_invite" class="text-sm">
            Invitar
          </.button>
          <.button :if={@is_owner} phx-click="toggle_edit">
            {if @editing, do: "Cancelar", else: "Editar"}
          </.button>
        </div>
      </div>

      <%!-- Edit form --%>
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
        <div class="flex flex-wrap gap-2">
          <span
            :for={m <- @members}
            class="px-3 py-1 bg-zinc-100 rounded-full text-sm font-medium"
          >
            {m.user.username}
            <span class="text-xs text-zinc-400 ml-1">{m.role}</span>
          </span>
        </div>
      </div>

      <%!-- Notes Section --%>
      <div class="border-t pt-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-lg font-semibold">Notas</h2>
          <.button phx-click="toggle_note_form" class="text-sm">
            {if @show_note_form, do: "Cancelar", else: "+ Nueva Nota"}
          </.button>
        </div>

        <div :if={@show_note_form} class="mb-4 p-4 bg-zinc-50 rounded-lg border">
          <.form for={@note_form} phx-submit="create_note" class="space-y-3">
            <.input field={@note_form[:title]} type="text" label="Título" required />
            <.input field={@note_form[:content]} type="textarea" label="Contenido" />
            <.button type="submit">Crear Nota</.button>
          </.form>
        </div>

        <div :if={@notes == []} class="text-center py-8 text-zinc-400">
          No hay notas aún. Crea la primera.
        </div>

        <div class="space-y-4">
          <div :for={note <- @notes} class="border rounded-lg p-4">
            <div class="flex items-center justify-between mb-3">
              <div>
                <h3 class="font-semibold text-lg">{note.title}</h3>
                <p :if={note.content} class="text-sm text-zinc-500 mt-1">{note.content}</p>
                <p :if={note.created_by} class="text-xs text-zinc-400 mt-1">
                  por {note.created_by.username}
                </p>
              </div>
              <button
                phx-click="delete_note"
                phx-value-id={note.id}
                data-confirm="¿Eliminar esta nota y todas sus tareas?"
                class="text-red-400 hover:text-red-600 text-sm"
              >
                Eliminar
              </button>
            </div>

            <%!-- Tasks --%>
            <div class="space-y-2">
              <div :for={task <- note.tasks} class="flex items-start gap-3 group">
                <%!-- Toggle slide --%>
                <button
                  phx-click="toggle_task"
                  phx-value-id={task.id}
                  class="mt-0.5 relative inline-flex h-6 w-11 flex-shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
                  style={
                    if task.completed,
                      do: "background-color: #22c55e",
                      else: "background-color: #d1d5db"
                  }
                >
                  <span
                    class="pointer-events-none inline-block h-5 w-5 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out"
                    style={
                      if task.completed,
                        do: "transform: translateX(1.25rem)",
                        else: "transform: translateX(0)"
                    }
                  />
                </button>
                <div class="flex-1 min-w-0">
                  <p class={"text-sm font-medium #{if task.completed, do: "line-through text-zinc-400", else: "text-zinc-900"}"}>
                    {task.title}
                  </p>

                  <%!-- Description --%>
                  <div :if={@editing_task == task.id} class="mt-1">
                    <textarea
                      phx-blur="save_task_description"
                      phx-value-id={task.id}
                      phx-keydown="save_task_description"
                      phx-key="Enter"
                      class="w-full text-xs border rounded p-1 resize-none"
                      rows="2"
                      phx-hook="TaskDescriptionInput"
                      id={"task-desc-#{task.id}"}
                    >{@task_description}</textarea>
                    <div class="flex gap-1 mt-1">
                      <button
                        phx-click="save_task_description"
                        phx-value-id={task.id}
                        class="text-xs text-blue-600 hover:underline"
                      >
                        Guardar
                      </button>
                      <button
                        phx-click="cancel_edit_description"
                        class="text-xs text-zinc-400 hover:underline"
                      >
                        Cancelar
                      </button>
                    </div>
                  </div>

                  <div :if={@editing_task != task.id}>
                    <p
                      :if={task.description && task.description != ""}
                      class="text-xs text-zinc-500 mt-0.5"
                    >
                      {task.description}
                    </p>
                    <button
                      phx-click="edit_task_description"
                      phx-value-id={task.id}
                      phx-value-description={task.description || ""}
                      class="text-xs text-zinc-300 hover:text-zinc-500 mt-0.5 opacity-0 group-hover:opacity-100 transition-opacity"
                    >
                      {if task.description, do: "editar descripción", else: "+ descripción"}
                    </button>
                  </div>

                  <p :if={task.completed && task.completed_by} class="text-xs text-green-600 mt-0.5">
                    completada por {task.completed_by.username}
                  </p>
                </div>
                <button
                  phx-click="delete_task"
                  phx-value-id={task.id}
                  class="text-red-300 hover:text-red-500 text-xs opacity-0 group-hover:opacity-100 transition-opacity"
                >
                  x
                </button>
              </div>
            </div>

            <%!-- Add task --%>
            <form phx-submit="add_task" class="mt-3 flex gap-2">
              <input type="hidden" name="note_id" value={note.id} />
              <input
                type="text"
                name="title"
                placeholder="Nueva tarea..."
                class="flex-1 text-sm border rounded px-2 py-1 focus:outline-none focus:ring-1 focus:ring-blue-500"
                autocomplete="off"
              />
              <button
                type="submit"
                class="px-3 py-1 bg-blue-500 text-white rounded text-sm hover:bg-blue-600"
              >
                Agregar
              </button>
            </form>
          </div>
        </div>
      </div>

      <%!-- Invite Modal --%>
      <div :if={@show_invite} class="fixed inset-0 z-40 flex items-center justify-center bg-black/50">
        <div class="bg-white rounded-lg shadow-xl p-6 w-96 max-h-96">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold">Invitar Usuario</h3>
            <button phx-click="toggle_invite" class="text-zinc-400 hover:text-zinc-600">x</button>
          </div>
          <input
            type="text"
            phx-keyup="search_users"
            phx-value-query={@invite_query}
            value={@invite_query}
            placeholder="Buscar por usuario o email..."
            class="w-full border rounded px-3 py-2 text-sm mb-3"
            autocomplete="off"
            name="query"
          />
          <div class="space-y-2 max-h-48 overflow-y-auto">
            <div
              :for={user <- @invite_results}
              class="flex items-center justify-between p-2 hover:bg-zinc-50 rounded"
            >
              <div>
                <span class="font-medium text-sm">{user.username}</span>
                <span class="text-xs text-zinc-400 ml-2">{user.email}</span>
              </div>
              <button
                phx-click="invite_user"
                phx-value-user_id={user.id}
                class="px-2 py-1 bg-blue-500 text-white rounded text-xs hover:bg-blue-600"
              >
                Invitar
              </button>
            </div>
            <p
              :if={@invite_results == [] && String.length(@invite_query) >= 2}
              class="text-sm text-zinc-400 text-center py-2"
            >
              No se encontraron usuarios
            </p>
          </div>
        </div>
      </div>

      <%!-- Chat Panel --%>
      <div
        :if={@show_chat}
        class="fixed bottom-0 right-4 w-96 bg-white border border-zinc-200 rounded-t-lg shadow-xl z-30"
      >
        <div class="flex items-center justify-between px-4 py-2 bg-zinc-900 text-white rounded-t-lg">
          <span class="font-semibold text-sm">Chat</span>
          <button phx-click="toggle_chat" class="text-zinc-300 hover:text-white">x</button>
        </div>
        <div class="h-72 overflow-y-auto p-3 space-y-2" id="chat-messages" phx-hook="ChatScroll">
          <div :for={msg <- @messages} class="text-sm">
            <span class="font-semibold text-zinc-700">{msg.user.username}:</span>
            <span class="text-zinc-600">{msg.body}</span>
            <span class="text-xs text-zinc-300 ml-1">
              {Calendar.strftime(msg.inserted_at, "%H:%M")}
            </span>
          </div>
          <p :if={@messages == []} class="text-center text-zinc-400 text-sm py-4">
            Sin mensajes aún
          </p>
        </div>
        <form phx-submit="send_message" class="border-t p-2 flex gap-2">
          <input
            type="text"
            name="body"
            placeholder="Escribe un mensaje..."
            class="flex-1 text-sm border rounded px-2 py-1 focus:outline-none focus:ring-1 focus:ring-blue-500"
            autocomplete="off"
          />
          <button
            type="submit"
            class="px-3 py-1 bg-blue-500 text-white rounded text-sm hover:bg-blue-600"
          >
            Enviar
          </button>
        </form>
      </div>
    </div>
    """
  end
end
