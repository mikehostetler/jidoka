defmodule Jidoka.Attempt do
  @moduledoc """
  Durable execution pass for a run.

  An attempt belongs to a run (`run_id`) and may reference one environment lease,
  verification result, and any artifacts produced during that pass.
  """
  alias Jidoka.Durable
  alias Jidoka.Durable.AttemptStatus

  @enforce_keys [:id, :version, :created_at, :updated_at, :status]
  defstruct [
    :id,
    :version,
    :created_at,
    :updated_at,
    :status,
    :run_id,
    :attempt_number,
    :environment_lease_id,
    :verification_result_id,
    :artifact_ids,
    :started_at,
    :finished_at,
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          status: AttemptStatus.t(),
          run_id: String.t(),
          attempt_number: pos_integer(),
          environment_lease_id: String.t() | nil,
          verification_result_id: String.t() | nil,
          artifact_ids: [String.t()],
          started_at: DateTime.t() | nil,
          finished_at: DateTime.t() | nil,
          metadata: map()
        }

  @spec new(keyword() | map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(attrs) when is_map(attrs) do
    now = Durable.now()

    attempt =
      struct(__MODULE__, %{
        id: attrs[:id],
        version: attrs[:version] || 1,
        created_at: attrs[:created_at] || now,
        updated_at: attrs[:updated_at] || now,
        status: attrs[:status] || AttemptStatus.default(),
        run_id: attrs[:run_id],
        attempt_number: attrs[:attempt_number] || 1,
        environment_lease_id: attrs[:environment_lease_id],
        verification_result_id: attrs[:verification_result_id],
        artifact_ids: Map.get(attrs, :artifact_ids, []),
        started_at: attrs[:started_at],
        finished_at: attrs[:finished_at],
        metadata: Map.get(attrs, :metadata, %{})
      })

    with :ok <- Durable.validate_id(attempt.id),
         :ok <- Durable.validate_id(attempt.run_id),
         :ok <- Durable.validate_version(attempt.version),
         :ok <- validate_attempt_number(attempt.attempt_number),
         :ok <- Durable.validate_datetime(attempt.created_at),
         :ok <- Durable.validate_datetime(attempt.updated_at),
         :ok <- maybe_validate_datetime(attempt.started_at),
         :ok <- maybe_validate_datetime(attempt.finished_at),
         :ok <- status_ok?(attempt.status),
         :ok <- validate_refs(attempt.artifact_ids),
         :ok <- validate_metadata(attempt.metadata) do
      {:ok, attempt}
    end
  end

  defp status_ok?(status) do
    if AttemptStatus.valid?(status) do
      :ok
    else
      {:error, {:invalid_status, AttemptStatus.values(), status}}
    end
  end

  defp validate_attempt_number(number) when is_integer(number) and number > 0, do: :ok
  defp validate_attempt_number(_), do: {:error, :invalid_attempt_number}

  defp maybe_validate_datetime(nil), do: :ok
  defp maybe_validate_datetime(value), do: Durable.validate_datetime(value)

  defp validate_refs(refs) when is_list(refs) do
    if Enum.all?(refs, &(is_binary(&1) and byte_size(&1) > 0)) do
      :ok
    else
      {:error, :invalid_artifact_ids}
    end
  end

  defp validate_refs(_), do: {:error, :invalid_artifact_ids}

  defp validate_metadata(meta) when is_map(meta), do: :ok
  defp validate_metadata(_), do: {:error, :invalid_metadata}
end
