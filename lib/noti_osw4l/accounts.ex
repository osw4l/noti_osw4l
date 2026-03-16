defmodule NotiOsw4l.Accounts do
  import Ecto.Query
  alias NotiOsw4l.Repo
  alias NotiOsw4l.Accounts.User

  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) do
    Repo.get_by(User, email: email)
  end

  def get_user_by_username(username) do
    Repo.get_by(User, username: username)
  end

  def list_users do
    Repo.all(from u in User, order_by: [asc: u.username])
  end

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :invalid_password}

      true ->
        Bcrypt.no_user_verify()
        {:error, :not_found}
    end
  end

  def change_user_registration(user \\ %User{}, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  def update_user_profile(user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  def search_users(query_string) do
    pattern = "%#{query_string}%"

    from(u in User,
      where: ilike(u.username, ^pattern) or ilike(u.email, ^pattern),
      order_by: [asc: u.username],
      limit: 20
    )
    |> Repo.all()
  end
end
