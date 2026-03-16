defmodule NotiOsw4l.Workspaces.Membership do
  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(owner admin member)
  @statuses ~w(pending accepted rejected)

  schema "workspace_memberships" do
    field :role, :string, default: "member"
    field :status, :string, default: "pending"

    belongs_to :workspace, NotiOsw4l.Workspaces.Workspace
    belongs_to :user, NotiOsw4l.Accounts.User
    belongs_to :invited_by, NotiOsw4l.Accounts.User

    timestamps()
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :status, :workspace_id, :user_id, :invited_by_id])
    |> validate_required([:role, :status, :workspace_id, :user_id])
    |> validate_inclusion(:role, @roles)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint([:workspace_id, :user_id])
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
  end

  def accept_changeset(membership) do
    change(membership, status: "accepted")
  end

  def reject_changeset(membership) do
    change(membership, status: "rejected")
  end
end
