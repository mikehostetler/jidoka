defmodule Jidoka.Run do
  @moduledoc """
  Durable record for one submitted coding task.

  A run belongs to a `Jidoka.Session` via `session_id` and owns one or more
  attempts. For MVP expansion support the run may carry `parent_run_id` and
  `role` as optional fields, but no child-run behavior is implemented here.
  """
  alias Jidoka.Durable
  alias Jidoka.Durable.{RunStatus, OutcomeStatus}

  @enforce_keys [:id, :version, :created_at, :updated_at, :status]
  defstruct [
    :id,
    :version,
    :created_at,
    :updated_at,
    :status,
    :session_id,
    :task,
    :task_pack,
    :outcome,
    :attempt_ids,
    :latest_attempt_id,
    :parent_run_id,
    :role,
    :artifact_ids
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          status: RunStatus.t(),
          session_id: String.t(),
          task: String.t(),
          task_pack: atom() | String.t(),
          outcome: OutcomeStatus.t() | nil,
          attempt_ids: [String.t()],
          latest_attempt_id: String.t() | nil,
          parent_run_id: String.t() | nil,
          role: atom() | nil,
          artifact_ids: [String.t()]
        }

  @spec new(keyword() | map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(attrs) when is_map(attrs) do
    now = Durable.now()

    run =
      struct(__MODULE__, %{
        id: attrs[:id],
        version: attrs[:version] || 1,
        created_at: attrs[:created_at] || now,
        updated_at: attrs[:updated_at] || now,
        status: attrs[:status] || RunStatus.default(),
        session_id: attrs[:session_id],
        task: attrs[:task],
        task_pack: attrs[:task_pack] || :coding,
        outcome: attrs[:outcome],
        attempt_ids: Map.get(attrs, :attempt_ids, []),
        latest_attempt_id: attrs[:latest_attempt_id],
        parent_run_id: attrs[:parent_run_id],
        role: attrs[:role],
        artifact_ids: Map.get(attrs, :artifact_ids, [])
      })

    with :ok <- Durable.validate_id(run.id),
         :ok <- Durable.validate_id(run.session_id),
         :ok <- Durable.validate_version(run.version),
         :ok <- Durable.validate_datetime(run.created_at),
         :ok <- Durable.validate_datetime(run.updated_at),
         :ok <- status_ok?(run.status),
         :ok <- validate_outcome(run.outcome),
         :ok <- validate_task(run.task),
         :ok <- validate_refs(run.attempt_ids),
         :ok <- validate_refs(run.artifact_ids) do
      {:ok, run}
    end
  end

  defp status_ok?(status) do
    if RunStatus.valid?(status) do
      :ok
    else
      {:error, {:invalid_status, RunStatus.values(), status}}
    end
  end

  defp validate_outcome(nil), do: :ok

  defp validate_outcome(outcome) do
    if OutcomeStatus.valid?(outcome) do
      :ok
    else
      {:error, {:invalid_outcome, OutcomeStatus.values(), outcome}}
    end
  end

  defp validate_task(task) when is_binary(task) and byte_size(task) > 0, do: :ok
  defp validate_task(_), do: {:error, :invalid_task}

  defp validate_refs(refs) when is_list(refs) do
    if Enum.all?(refs, &(is_binary(&1) and byte_size(&1) > 0)) do
      :ok
    else
      {:error, :invalid_ids}
    end
  end

  defp validate_refs(_), do: {:error, :invalid_ids}
end
