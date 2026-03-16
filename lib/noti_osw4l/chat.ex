defmodule NotiOsw4l.Chat do
  import Ecto.Query
  alias NotiOsw4l.Repo
  alias NotiOsw4l.Chat.Message

  def list_messages(workspace_id, limit \\ 50) do
    from(m in Message,
      where: m.workspace_id == ^workspace_id,
      order_by: [desc: m.inserted_at],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  def create_message(attrs) do
    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} -> {:ok, Repo.preload(message, :user)}
      error -> error
    end
  end
end
