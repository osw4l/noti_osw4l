defmodule NotiOsw4l.Activity.Log do
  use Ecto.Schema
  import Ecto.Changeset

  schema "activity_logs" do
    field :action, :string
    field :entity_type, :string
    field :entity_id, :integer
    field :metadata, :map, default: %{}

    belongs_to :workspace, NotiOsw4l.Workspaces.Workspace
    belongs_to :user, NotiOsw4l.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:action, :entity_type, :entity_id, :metadata, :workspace_id, :user_id])
    |> validate_required([:action, :entity_type, :workspace_id, :user_id])
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
  end
end
