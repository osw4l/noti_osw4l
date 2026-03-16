defmodule NotiOsw4l.Notes.Task do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tasks" do
    field :title, :string
    field :description, :string
    field :completed, :boolean, default: false
    field :position, :integer, default: 0
    field :completed_at, :utc_datetime

    belongs_to :note, NotiOsw4l.Notes.Note
    belongs_to :created_by, NotiOsw4l.Accounts.User
    belongs_to :completed_by, NotiOsw4l.Accounts.User

    timestamps()
  end

  def changeset(task, attrs) do
    task
    |> cast(attrs, [:title, :description, :position, :note_id, :created_by_id])
    |> validate_required([:title, :note_id])
    |> validate_length(:title, min: 1, max: 500)
    |> foreign_key_constraint(:note_id)
  end

  def toggle_changeset(task, user_id) do
    completed = !task.completed

    changes =
      if completed do
        %{
          completed: true,
          completed_by_id: user_id,
          completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        }
      else
        %{completed: false, completed_by_id: nil, completed_at: nil}
      end

    change(task, changes)
  end
end
