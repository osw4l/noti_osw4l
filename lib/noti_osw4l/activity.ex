defmodule NotiOsw4l.Activity do
  import Ecto.Query
  alias NotiOsw4l.Repo
  alias NotiOsw4l.Activity.Log

  def list_logs(workspace_id, limit \\ 50) do
    from(l in Log,
      where: l.workspace_id == ^workspace_id,
      order_by: [desc: l.inserted_at],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  def log_action(attrs) do
    %Log{}
    |> Log.changeset(attrs)
    |> Repo.insert()
  end
end
