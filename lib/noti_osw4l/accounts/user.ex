defmodule NotiOsw4l.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :username, :string
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :display_name, :string
    field :avatar_url, :string
    field :last_seen_at, :utc_datetime

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :email, :password, :display_name])
    |> validate_required([:username, :email, :password])
    |> validate_length(:username, min: 3, max: 30)
    |> validate_format(:username, ~r/^[a-zA-Z0-9_]+$/,
      message: "solo letras, números y guiones bajos"
    )
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "debe ser un email válido")
    |> validate_length(:password, min: 6, max: 72)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> hash_password()
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, [:display_name, :avatar_url])
  end

  defp hash_password(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp hash_password(changeset), do: changeset
end
