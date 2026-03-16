defmodule NotiOsw4l.Workspaces.Workspace do
  use Ecto.Schema
  import Ecto.Changeset

  schema "workspaces" do
    field :name, :string
    field :description, :string

    belongs_to :owner, NotiOsw4l.Accounts.User
    has_many :memberships, NotiOsw4l.Workspaces.Membership
    has_many :members, through: [:memberships, :user]

    timestamps()
  end

  def changeset(workspace, attrs) do
    workspace
    |> cast(attrs, [:name, :description, :owner_id])
    |> validate_required([:name, :owner_id])
    |> validate_length(:name, min: 1, max: 100)
    |> foreign_key_constraint(:owner_id)
  end
end
