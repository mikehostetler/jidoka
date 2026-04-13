defmodule Jidoka.Artifact do
  @moduledoc """
  Durable artifact record for files produced by attempts and sessions.
  """
  alias Jidoka.Durable
  alias Jidoka.Durable.{ArtifactStatus, ArtifactType}

  @enforce_keys [:id, :version, :created_at, :updated_at, :status]
  defstruct [
    :id,
    :version,
    :created_at,
    :updated_at,
    :status,
    :type,
    :run_id,
    :attempt_id,
    :location,
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          status: ArtifactStatus.t(),
          type: ArtifactType.t(),
          run_id: String.t() | nil,
          attempt_id: String.t() | nil,
          location: String.t() | nil,
          metadata: map()
        }

  @spec new(keyword() | map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(attrs) when is_map(attrs) do
    now = Durable.now()

    artifact =
      struct(__MODULE__, %{
        id: attrs[:id],
        version: attrs[:version] || 1,
        created_at: attrs[:created_at] || now,
        updated_at: attrs[:updated_at] || now,
        status: attrs[:status] || ArtifactStatus.default(),
        type: attrs[:type] || :transcript,
        run_id: attrs[:run_id],
        attempt_id: attrs[:attempt_id],
        location: attrs[:location],
        metadata: Map.get(attrs, :metadata, %{})
      })

    with :ok <- Durable.validate_id(artifact.id),
         :ok <- Durable.validate_version(artifact.version),
         :ok <- Durable.validate_datetime(artifact.created_at),
         :ok <- Durable.validate_datetime(artifact.updated_at),
         :ok <- status_ok?(artifact.status),
         :ok <- type_ok?(artifact.type),
         :ok <- optional_id_ok?(artifact.run_id),
         :ok <- optional_id_ok?(artifact.attempt_id),
         :ok <- validate_metadata(artifact.metadata) do
      {:ok, artifact}
    end
  end

  defp status_ok?(status) do
    if ArtifactStatus.valid?(status) do
      :ok
    else
      {:error, {:invalid_status, ArtifactStatus.values(), status}}
    end
  end

  defp type_ok?(type) do
    if ArtifactType.valid?(type) do
      :ok
    else
      {:error, {:invalid_artifact_type, ArtifactType.values(), type}}
    end
  end

  defp optional_id_ok?(nil), do: :ok

  defp optional_id_ok?(id), do: Durable.validate_id(id)

  defp validate_metadata(meta) when is_map(meta), do: :ok
  defp validate_metadata(_), do: {:error, :invalid_metadata}
end
