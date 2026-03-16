defmodule NotiOsw4l.Notes do
  import Ecto.Query
  alias NotiOsw4l.Repo
  alias NotiOsw4l.Notes.{Note, Task}

  def list_notes(workspace_id) do
    from(n in Note,
      where: n.workspace_id == ^workspace_id,
      order_by: [asc: n.position, desc: n.inserted_at],
      preload: [tasks: :completed_by, created_by: []]
    )
    |> Repo.all()
  end

  def get_note!(id) do
    Note
    |> Repo.get!(id)
    |> Repo.preload(tasks: :completed_by, created_by: [])
  end

  def create_note(attrs) do
    %Note{}
    |> Note.changeset(attrs)
    |> Repo.insert()
  end

  def update_note(note, attrs) do
    note
    |> Note.changeset(attrs)
    |> Repo.update()
  end

  def delete_note(note) do
    Repo.delete(note)
  end

  def change_note(note \\ %Note{}, attrs \\ %{}) do
    Note.changeset(note, attrs)
  end

  def create_task(attrs) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, task} -> {:ok, Repo.preload(task, [:completed_by, :created_by])}
      error -> error
    end
  end

  def toggle_task(task_id, user_id) do
    task = Repo.get!(Task, task_id)

    task
    |> Task.toggle_changeset(user_id)
    |> Repo.update()
    |> case do
      {:ok, task} -> {:ok, Repo.preload(task, [:completed_by, :created_by])}
      error -> error
    end
  end

  def update_task(task_id, attrs) do
    Repo.get!(Task, task_id)
    |> Task.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, task} -> {:ok, Repo.preload(task, [:completed_by, :created_by])}
      error -> error
    end
  end

  def delete_task(task_id) do
    Repo.get!(Task, task_id) |> Repo.delete()
  end
end
