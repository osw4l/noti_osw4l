defmodule NotiOsw4l.Notifications do
  import Ecto.Query
  alias NotiOsw4l.Repo
  alias NotiOsw4l.Notifications.Notification

  def list_unread(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and n.read == false,
      order_by: [desc: n.inserted_at],
      limit: 20
    )
    |> Repo.all()
  end

  def unread_count(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and n.read == false,
      select: count()
    )
    |> Repo.one()
  end

  def mark_as_read(notification_id, user_id) do
    from(n in Notification,
      where: n.id == ^notification_id and n.user_id == ^user_id
    )
    |> Repo.update_all(set: [read: true])
  end

  def mark_all_as_read(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and n.read == false
    )
    |> Repo.update_all(set: [read: true])
  end

  @doc """
  Creates a notification and broadcasts it to the user via PubSub.
  """
  def notify(user_id, type, title, body \\ nil, metadata \\ %{}) do
    attrs = %{
      user_id: user_id,
      type: type,
      title: title,
      body: body,
      metadata: metadata
    }

    case %Notification{} |> Notification.changeset(attrs) |> Repo.insert() do
      {:ok, notification} ->
        Phoenix.PubSub.broadcast(
          NotiOsw4l.PubSub,
          "notifications:#{user_id}",
          {:new_notification, notification}
        )

        {:ok, notification}

      error ->
        error
    end
  end
end
