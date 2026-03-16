defmodule NotiOsw4l.Repo.Migrations.CreateActivityLogs do
  use Ecto.Migration

  def change do
    create table(:activity_logs) do
      add :action, :string, null: false
      add :entity_type, :string, null: false
      add :entity_id, :integer
      add :metadata, :map, default: %{}
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(updated_at: false)
    end

    create index(:activity_logs, [:workspace_id, :inserted_at])
    create index(:activity_logs, [:user_id])
    create index(:activity_logs, [:entity_type, :entity_id])
  end
end
