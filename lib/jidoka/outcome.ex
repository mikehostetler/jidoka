defmodule Jidoka.Outcome do
  @moduledoc """
  Stable typed outcome of a run-level result.
  """
  alias Jidoka.Durable
  alias Jidoka.Durable.OutcomeStatus

  @enforce_keys [:id, :version, :created_at, :updated_at, :outcome]
  defstruct [
    :id,
    :version,
    :created_at,
    :updated_at,
    :outcome,
    :run_id,
    :attempt_id,
    :notes
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          version: pos_integer(),
          created_at: DateTime.t(),
          updated_at: DateTime.t(),
          outcome: OutcomeStatus.t(),
          run_id: String.t(),
          attempt_id: String.t() | nil,
          notes: String.t() | nil
        }

  @spec new(keyword() | map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_list(attrs), do: new(Map.new(attrs))

  def new(attrs) when is_map(attrs) do
    now = Durable.now()

    outcome =
      struct(__MODULE__, %{
        id: attrs[:id],
        version: attrs[:version] || 1,
        created_at: attrs[:created_at] || now,
        updated_at: attrs[:updated_at] || now,
        outcome: attrs[:outcome] || OutcomeStatus.default(),
        run_id: attrs[:run_id],
        attempt_id: attrs[:attempt_id],
        notes: attrs[:notes]
      })

    with :ok <- Durable.validate_id(outcome.id),
         :ok <- Durable.validate_id(outcome.run_id),
         :ok <- Durable.validate_version(outcome.version),
         :ok <- Durable.validate_datetime(outcome.created_at),
         :ok <- Durable.validate_datetime(outcome.updated_at),
         :ok <- outcome_ok?(outcome.outcome),
         :ok <- optional_id_ok?(outcome.attempt_id),
         :ok <- notes_ok?(outcome.notes) do
      {:ok, outcome}
    end
  end

  defp outcome_ok?(value) do
    if OutcomeStatus.valid?(value) do
      :ok
    else
      {:error, {:invalid_outcome, OutcomeStatus.values(), value}}
    end
  end

  defp optional_id_ok?(nil), do: :ok
  defp optional_id_ok?(id), do: Durable.validate_id(id)

  defp notes_ok?(nil), do: :ok
  defp notes_ok?(note) when is_binary(note), do: :ok
  defp notes_ok?(_), do: {:error, :invalid_notes}
end
