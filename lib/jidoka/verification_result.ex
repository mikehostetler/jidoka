defmodule Jidoka.VerificationResult do
  @moduledoc """
  Durable outcome of verifier execution.
  """
  alias Jidoka.Durable
  alias Jidoka.Durable.VerificationResultStatus

  @enforce_keys [:id, :version, :created_at, :updated_at, :status]
  defstruct [
    :id,
    :version,
    :created_at,
    :updated_at,
    :status,
    :attempt_id,
    :outcome_summary,
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          status: VerificationResultStatus.t(),
          attempt_id: String.t(),
          outcome_summary: map(),
          metadata: map()
        }

  @spec new(keyword() | map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(attrs) when is_map(attrs) do
    now = Durable.now()

    result =
      struct(__MODULE__, %{
        id: attrs[:id],
        version: attrs[:version] || 1,
        created_at: attrs[:created_at] || now,
        updated_at: attrs[:updated_at] || now,
        status: attrs[:status] || VerificationResultStatus.default(),
        attempt_id: attrs[:attempt_id],
        outcome_summary: Map.get(attrs, :outcome_summary, %{}),
        metadata: Map.get(attrs, :metadata, %{})
      })

    with :ok <- Durable.validate_id(result.id),
         :ok <- Durable.validate_id(result.attempt_id),
         :ok <- Durable.validate_version(result.version),
         :ok <- Durable.validate_datetime(result.created_at),
         :ok <- Durable.validate_datetime(result.updated_at),
         :ok <- status_ok?(result.status),
         :ok <- validate_map(result.outcome_summary),
         :ok <- validate_map(result.metadata) do
      {:ok, result}
    end
  end

  defp status_ok?(status) do
    if VerificationResultStatus.valid?(status) do
      :ok
    else
      {:error, {:invalid_status, VerificationResultStatus.values(), status}}
    end
  end

  defp validate_map(map) when is_map(map), do: :ok
  defp validate_map(_), do: {:error, :invalid_map}
end
