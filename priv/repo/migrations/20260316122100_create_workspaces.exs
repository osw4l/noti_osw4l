defmodule NotiOsw4l.Repo.Migrations.CreateWorkspaces do
  use Ecto.Migration

  def change do
    create table(:workspaces) do
      add :name, :string, null: false
      add :description, :text
      add :owner_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:workspaces, [:owner_id])

    create table(:workspace_memberships) do
      add :role, :string, null: false, default: "member"
      add :status, :string, null: false, default: "pending"
      add :workspace_id, references(:workspaces, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :invited_by_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:workspace_memberships, [:workspace_id, :user_id])
    create index(:workspace_memberships, [:user_id])
    create index(:workspace_memberships, [:status])
  end
end
