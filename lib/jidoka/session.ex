defmodule Jidoka.Session do
  @moduledoc """
  Durable session envelope.

  A session represents a workspace interaction and owns a list of run identifiers.
  `Jidoka.Run` entities reference `session_id`; runs are the durable records for
  submitted tasks. Attempts live beneath runs, never directly under sessions.
  """
  alias Jidoka.Durable
  alias Jidoka.Durable.SessionStatus

  @enforce_keys [:id, :version, :created_at, :updated_at, :status]
  defstruct [
    :id,
    :version,
    :created_at,
    :updated_at,
    :status,
    :workspace_path,
    :run_ids,
    :active_run_id,
    :metadata
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          status: SessionStatus.t(),
          workspace_path: String.t() | nil,
          run_ids: [String.t()],
          active_run_id: String.t() | nil,
          metadata: map()
        }

  @spec new(keyword() | map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(attrs) when is_map(attrs) do
    now = Durable.now()

    session =
      struct(__MODULE__, %{
        id: attrs[:id],
        version: attrs[:version] || 1,
        created_at: attrs[:created_at] || now,
        updated_at: attrs[:updated_at] || now,
        status: attrs[:status] || SessionStatus.default(),
        workspace_path: attrs[:workspace_path],
        run_ids: Map.get(attrs, :run_ids, []),
        active_run_id: attrs[:active_run_id],
        metadata: Map.get(attrs, :metadata, %{})
      })

    with :ok <- Durable.validate_id(session.id),
         :ok <- Durable.validate_version(session.version),
         :ok <- Durable.validate_datetime(session.created_at),
         :ok <- Durable.validate_datetime(session.updated_at),
         :ok <- status_ok?(session.status),
         :ok <- validate_runs(session.run_ids),
         :ok <- validate_metadata(session.metadata) do
      {:ok, session}
    end
  end

  defp status_ok?(status) do
    if SessionStatus.valid?(status) do
      :ok
    else
      {:error, {:invalid_status, SessionStatus.values(), status}}
    end
  end

  defp validate_runs(runs) when is_list(runs) do
    if Enum.all?(runs, &(is_binary(&1) and byte_size(&1) > 0)) do
      :ok
    else
      {:error, :invalid_run_ids}
    end
  end

  defp validate_runs(_), do: {:error, :invalid_run_ids}

  defp validate_metadata(meta) when is_map(meta), do: :ok
  defp validate_metadata(_), do: {:error, :invalid_metadata}
end
