defmodule Jidoka.Persistence do
  @moduledoc """
  Persistence boundary for MVP durable entities.

  The runtime uses this boundary to read and write durable state.
  No live process identifiers are persisted at this layer; all records here are
  typed structs and ordered transition/event records.
  """

  alias Jidoka.{
    Attempt,
    Artifact,
    EnvironmentLease,
    Event,
    Outcome,
    Run,
    Session,
    VerificationResult
  }

  @type session_id :: String.t()
  @type storage :: term()
  @type event_sequence :: non_neg_integer()

  defmodule EventRecord do
    @moduledoc """
    Ordered event entry for one session.
    """
    alias Jidoka.Durable

    @enforce_keys [:session_id, :sequence, :event, :recorded_at]
    defstruct [:session_id, :sequence, :event, :recorded_at]

    @type t :: %__MODULE__{
            session_id: String.t(),
            sequence: non_neg_integer(),
            event: Event.t(),
            recorded_at: DateTime.t()
          }

    @spec new(String.t(), event_sequence(), Event.t()) :: t()
    def new(session_id, sequence, event) do
      %__MODULE__{
        session_id: session_id,
        sequence: sequence,
        event: event,
        recorded_at: Durable.now()
      }
    end
  end

  defmodule SessionEnvelope do
    @moduledoc """
    Reconstructed session materialization from persisted rows.
    """
    @enforce_keys [
      :session,
      :runs,
      :attempts,
      :leases,
      :artifacts,
      :verification_results,
      :outcomes,
      :events
    ]
    defstruct [
      :session,
      :runs,
      :attempts,
      :leases,
      :artifacts,
      :verification_results,
      :outcomes,
      :events
    ]

    @type t :: %__MODULE__{
            session: Session.t(),
            runs: [Run.t()],
            attempts: [Attempt.t()],
            leases: [EnvironmentLease.t()],
            artifacts: [Artifact.t()],
            verification_results: [VerificationResult.t()],
            outcomes: [Outcome.t()],
            events: [EventRecord.t()]
          }
  end

  @callback save_session(storage, Session.t()) ::
              {:ok, storage} | {:error, term()}
  @callback load_session(storage, session_id()) ::
              {:ok, Session.t()} | {:error, :not_found}
  @callback list_runs_for_session(storage, session_id()) ::
              {:ok, [Run.t()]} | {:error, :not_found}
  @callback save_run(storage, Run.t()) :: {:ok, storage} | {:error, term()}
  @callback load_run(storage, String.t()) ::
              {:ok, Run.t()} | {:error, :not_found}
  @callback list_attempts_for_run(storage, String.t()) ::
              {:ok, [Attempt.t()]} | {:error, :not_found}
  @callback list_attempts_for_session(storage, session_id()) ::
              {:ok, [Attempt.t()]} | {:error, :not_found}
  @callback save_attempt(storage, Attempt.t()) ::
              {:ok, storage} | {:error, term()}
  @callback load_attempt(storage, String.t()) ::
              {:ok, Attempt.t()} | {:error, :not_found}
  @callback save_environment_lease(storage, EnvironmentLease.t()) ::
              {:ok, storage} | {:error, term()}
  @callback load_environment_lease(storage, String.t()) ::
              {:ok, EnvironmentLease.t()} | {:error, :not_found}
  @callback list_environment_leases_for_session(storage, session_id()) ::
              {:ok, [EnvironmentLease.t()]} | {:error, :not_found}
  @callback save_artifact(storage, Artifact.t()) ::
              {:ok, storage} | {:error, term()}
  @callback load_artifact(storage, String.t()) ::
              {:ok, Artifact.t()} | {:error, :not_found}
  @callback list_artifacts_for_run(storage, String.t()) ::
              {:ok, [Artifact.t()]} | {:error, :not_found}
  @callback list_artifacts_for_session(storage, session_id()) ::
              {:ok, [Artifact.t()]} | {:error, :not_found}
  @callback save_verification_result(storage, VerificationResult.t()) ::
              {:ok, storage} | {:error, term()}
  @callback load_verification_result(storage, String.t()) ::
              {:ok, VerificationResult.t()} | {:error, :not_found}
  @callback list_verification_results_for_session(storage, session_id()) ::
              {:ok, [VerificationResult.t()]} | {:error, :not_found}
  @callback save_outcome(storage, Outcome.t()) ::
              {:ok, storage} | {:error, term()}
  @callback load_outcome(storage, String.t()) ::
              {:ok, Outcome.t()} | {:error, :not_found}
  @callback list_outcomes_for_session(storage, session_id()) ::
              {:ok, [Outcome.t()]} | {:error, :not_found}
  @callback append_event(storage, Event.t()) ::
              {:ok, storage, EventRecord.t()} | {:error, term()}
  @callback list_events_for_session(storage, session_id()) ::
              {:ok, [EventRecord.t()]} | {:error, :not_found}
  @callback load_session_envelope(storage, session_id()) ::
              {:ok, SessionEnvelope.t()} | {:error, :not_found}
end
