defmodule NotiOsw4l.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :username, :string, null: false
      add :email, :citext, null: false
      add :password_hash, :string, null: false
      add :display_name, :string
      add :avatar_url, :string

      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
  end
end
