defmodule NotiOsw4l.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :type, :string
    field :title, :string
    field :body, :string
    field :read, :boolean, default: false
    field :metadata, :map, default: %{}

    belongs_to :user, NotiOsw4l.Accounts.User

    timestamps()
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [:type, :title, :body, :read, :metadata, :user_id])
    |> validate_required([:type, :title, :user_id])
  end
end
