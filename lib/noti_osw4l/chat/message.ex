defmodule NotiOsw4l.Chat.Message do
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :body, :string

    belongs_to :workspace, NotiOsw4l.Workspaces.Workspace
    belongs_to :user, NotiOsw4l.Accounts.User

    timestamps()
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :workspace_id, :user_id])
    |> validate_required([:body, :workspace_id, :user_id])
    |> validate_length(:body, min: 1, max: 5000)
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
  end
end
