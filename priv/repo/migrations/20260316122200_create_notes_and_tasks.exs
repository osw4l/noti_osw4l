defmodule NotiOsw4l.Repo.Migrations.CreateNotesAndTasks do
  use Ecto.Migration

  def change do
    create table(:notes) do
      add :title, :string, null: false
      add :content, :text
      add :position, :integer, default: 0
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:notes, [:workspace_id])

    create table(:tasks) do
      add :title, :string, null: false
      add :description, :text
      add :completed, :boolean, default: false, null: false
      add :position, :integer, default: 0
      add :note_id, references(:notes, on_delete: :delete_all), null: false
      add :created_by_id, references(:users, on_delete: :nilify_all)
      add :completed_by_id, references(:users, on_delete: :nilify_all)
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:tasks, [:note_id])
    create index(:tasks, [:completed])
  end
end
