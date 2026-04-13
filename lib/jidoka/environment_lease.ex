defmodule Jidoka.EnvironmentLease do
  @moduledoc """
  Durable record for workspace write access during an attempt.
  """
  alias Jidoka.Durable
  alias Jidoka.Durable.{EnvironmentLeaseMode, EnvironmentLeaseStatus}

  @enforce_keys [:id, :version, :created_at, :updated_at, :status]
  defstruct [
    :id,
    :version,
    :created_at,
    :updated_at,
    :status,
    :mode,
    :attempt_id,
    :workspace_path,
    :expires_at,
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          status: EnvironmentLeaseStatus.t(),
          mode: EnvironmentLeaseMode.t(),
          attempt_id: String.t(),
          workspace_path: String.t() | nil,
          expires_at: DateTime.t() | nil,
          metadata: map()
        }

  @spec new(keyword() | map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(attrs) when is_map(attrs) do
    now = Durable.now()

    lease =
      struct(__MODULE__, %{
        id: attrs[:id],
        version: attrs[:version] || 1,
        created_at: attrs[:created_at] || now,
        updated_at: attrs[:updated_at] || now,
        status: attrs[:status] || EnvironmentLeaseStatus.default(),
        mode: attrs[:mode] || EnvironmentLeaseMode.default(),
        attempt_id: attrs[:attempt_id],
        workspace_path: attrs[:workspace_path],
        expires_at: attrs[:expires_at],
        metadata: Map.get(attrs, :metadata, %{})
      })

    with :ok <- Durable.validate_id(lease.id),
         :ok <- Durable.validate_id(lease.attempt_id),
         :ok <- Durable.validate_version(lease.version),
         :ok <- Durable.validate_datetime(lease.created_at),
         :ok <- Durable.validate_datetime(lease.updated_at),
         :ok <- status_ok?(lease.status),
         :ok <- mode_ok?(lease.mode),
         :ok <- maybe_validate_datetime(lease.expires_at),
         :ok <- validate_metadata(lease.metadata) do
      {:ok, lease}
    end
  end

  defp status_ok?(status) do
    if EnvironmentLeaseStatus.valid?(status) do
      :ok
    else
      {:error, {:invalid_status, EnvironmentLeaseStatus.values(), status}}
    end
  end

  defp mode_ok?(mode) do
    if EnvironmentLeaseMode.valid?(mode) do
      :ok
    else
      {:error, {:invalid_mode, EnvironmentLeaseMode.values(), mode}}
    end
  end

  defp maybe_validate_datetime(nil), do: :ok
  defp maybe_validate_datetime(value), do: Durable.validate_datetime(value)

  defp validate_metadata(meta) when is_map(meta), do: :ok
  defp validate_metadata(_), do: {:error, :invalid_metadata}
end
