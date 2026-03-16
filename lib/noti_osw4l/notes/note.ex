defmodule NotiOsw4l.Notes.Note do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notes" do
    field :title, :string
    field :content, :string
    field :position, :integer, default: 0

    belongs_to :workspace, NotiOsw4l.Workspaces.Workspace
    belongs_to :created_by, NotiOsw4l.Accounts.User
    has_many :tasks, NotiOsw4l.Notes.Task, preload_order: [asc: :position]

    timestamps()
  end

  def changeset(note, attrs) do
    note
    |> cast(attrs, [:title, :content, :position, :workspace_id, :created_by_id])
    |> validate_required([:title, :workspace_id])
    |> validate_length(:title, min: 1, max: 200)
    |> foreign_key_constraint(:workspace_id)
  end
end
