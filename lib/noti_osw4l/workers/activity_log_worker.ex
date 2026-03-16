defmodule NotiOsw4l.Workers.ActivityLogWorker do
  use Oban.Worker, queue: :activity, max_attempts: 3

  alias NotiOsw4l.Activity

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    %{
      "action" => action,
      "entity_type" => entity_type,
      "workspace_id" => workspace_id,
      "user_id" => user_id
    } = args

    Activity.log_action(%{
      action: action,
      entity_type: entity_type,
      entity_id: args["entity_id"],
      metadata: args["metadata"] || %{},
      workspace_id: workspace_id,
      user_id: user_id
    })

    :ok
  end

  def enqueue(action, entity_type, entity_id, workspace_id, user_id, metadata \\ %{}) do
    %{
      action: action,
      entity_type: entity_type,
      entity_id: entity_id,
      workspace_id: workspace_id,
      user_id: user_id,
      metadata: metadata
    }
    |> __MODULE__.new()
    |> Oban.insert()
  end
end
