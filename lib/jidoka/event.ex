defmodule Jidoka.Event do
  @moduledoc """
  Append-only durable event emitted by the runtime.
  """
  alias Jidoka.Durable
  alias Jidoka.Durable.{EventStatus, EventType}

  @enforce_keys [:id, :version, :created_at, :updated_at, :status]
  defstruct [
    :id,
    :version,
    :created_at,
    :updated_at,
    :status,
    :type,
    :session_id,
    :run_id,
    :attempt_id,
    :payload
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          status: EventStatus.t(),
          type: EventType.t(),
          session_id: String.t(),
          run_id: String.t() | nil,
          attempt_id: String.t() | nil,
          payload: map()
        }

  @spec new(keyword() | map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(attrs) when is_map(attrs) do
    now = Durable.now()

    event =
      struct(__MODULE__, %{
        id: attrs[:id],
        version: attrs[:version] || 1,
        created_at: attrs[:created_at] || now,
        updated_at: attrs[:updated_at] || now,
        status: attrs[:status] || EventStatus.default(),
        type: attrs[:type] || :session_opened,
        session_id: attrs[:session_id],
        run_id: attrs[:run_id],
        attempt_id: attrs[:attempt_id],
        payload: Map.get(attrs, :payload, %{})
      })

    with :ok <- Durable.validate_id(event.id),
         :ok <- Durable.validate_id(event.session_id),
         :ok <- Durable.validate_version(event.version),
         :ok <- Durable.validate_datetime(event.created_at),
         :ok <- Durable.validate_datetime(event.updated_at),
         :ok <- status_ok?(event.status),
         :ok <- type_ok?(event.type),
         :ok <- optional_id_ok?(event.run_id),
         :ok <- optional_id_ok?(event.attempt_id),
         :ok <- payload_ok?(event.payload) do
      {:ok, event}
    end
  end

  defp status_ok?(status) do
    if EventStatus.valid?(status) do
      :ok
    else
      {:error, {:invalid_status, EventStatus.values(), status}}
    end
  end

  defp type_ok?(type) do
    if EventType.valid?(type) do
      :ok
    else
      {:error, {:invalid_type, EventType.values(), type}}
    end
  end

  defp optional_id_ok?(nil), do: :ok
  defp optional_id_ok?(id), do: Durable.validate_id(id)

  defp payload_ok?(payload) when is_map(payload), do: :ok
  defp payload_ok?(_), do: {:error, :invalid_payload}
end
