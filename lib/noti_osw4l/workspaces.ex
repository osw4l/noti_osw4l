defmodule NotiOsw4l.Workspaces do
  import Ecto.Query
  alias NotiOsw4l.Repo
  alias NotiOsw4l.Workspaces.{Workspace, Membership}

  def list_workspaces_for_user(user_id) do
    from(w in Workspace,
      left_join: m in Membership,
      on: m.workspace_id == w.id and m.user_id == ^user_id,
      where: w.owner_id == ^user_id or (m.user_id == ^user_id and m.status == "accepted"),
      distinct: true,
      order_by: [desc: w.updated_at],
      preload: [:owner]
    )
    |> Repo.all()
  end

  def get_workspace!(id) do
    Workspace
    |> Repo.get!(id)
    |> Repo.preload([:owner, memberships: :user])
  end

  def create_workspace(attrs, owner_id) do
    Repo.transaction(fn ->
      workspace =
        %Workspace{}
        |> Workspace.changeset(Map.put(attrs, "owner_id", owner_id))
        |> Repo.insert!()

      %Membership{}
      |> Membership.changeset(%{
        workspace_id: workspace.id,
        user_id: owner_id,
        role: "owner",
        status: "accepted"
      })
      |> Repo.insert!()

      workspace
    end)
  end

  def update_workspace(workspace, attrs) do
    workspace
    |> Workspace.changeset(attrs)
    |> Repo.update()
  end

  def delete_workspace(workspace) do
    Repo.delete(workspace)
  end

  def change_workspace(workspace \\ %Workspace{}, attrs \\ %{}) do
    Workspace.changeset(workspace, attrs)
  end

  def user_has_access?(workspace_id, user_id) do
    workspace = Repo.get!(Workspace, workspace_id)

    if workspace.owner_id == user_id do
      true
    else
      Repo.exists?(
        from(m in Membership,
          where:
            m.workspace_id == ^workspace_id and
              m.user_id == ^user_id and
              m.status == "accepted"
        )
      )
    end
  end

  def invite_user(workspace_id, user_id, invited_by_id) do
    %Membership{}
    |> Membership.changeset(%{
      workspace_id: workspace_id,
      user_id: user_id,
      invited_by_id: invited_by_id,
      role: "member",
      status: "pending"
    })
    |> Repo.insert()
  end

  def request_access(workspace_id, user_id) do
    %Membership{}
    |> Membership.changeset(%{
      workspace_id: workspace_id,
      user_id: user_id,
      role: "member",
      status: "pending"
    })
    |> Repo.insert()
  end

  def accept_membership(membership_id) do
    Repo.get!(Membership, membership_id)
    |> Membership.accept_changeset()
    |> Repo.update()
  end

  def reject_membership(membership_id) do
    Repo.get!(Membership, membership_id)
    |> Membership.reject_changeset()
    |> Repo.update()
  end

  def pending_requests(workspace_id) do
    from(m in Membership,
      where: m.workspace_id == ^workspace_id and m.status == "pending",
      preload: [:user]
    )
    |> Repo.all()
  end

  def workspace_members(workspace_id) do
    from(m in Membership,
      where: m.workspace_id == ^workspace_id and m.status == "accepted",
      preload: [:user]
    )
    |> Repo.all()
  end

  def is_owner?(workspace, user_id) do
    workspace.owner_id == user_id
  end
end
