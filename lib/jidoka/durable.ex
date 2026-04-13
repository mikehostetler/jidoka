defmodule Jidoka.Durable do
  @moduledoc """
  Shared status vocabularies and validation helpers for MVP durable entities.
  """

  defmodule SessionStatus do
    @moduledoc """
    Lifecycle for `Jidoka.Session`.
    """
    @type t :: :initializing | :active | :closed
    @values [:initializing, :active, :closed]

    @spec values() :: [t()]
    def values, do: @values

    @spec default() :: t()
    def default, do: :initializing

    @spec valid?(term()) :: boolean()
    def valid?(value), do: value in @values
  end

  defmodule RunStatus do
    @moduledoc """
    Lifecycle for `Jidoka.Run`.
    """
    @type t ::
            :queued
            | :running
            | :awaiting_approval
            | :completed
            | :failed
            | :canceled
    @values [:queued, :running, :awaiting_approval, :completed, :failed, :canceled]

    @spec values() :: [t()]
    def values, do: @values

    @spec default() :: t()
    def default, do: :queued

    @spec valid?(term()) :: boolean()
    def valid?(value), do: value in @values
  end

  defmodule AttemptStatus do
    @moduledoc """
    Lifecycle for `Jidoka.Attempt`.
    """
    @type t ::
            :pending
            | :running
            | :succeeded
            | :retryable_failed
            | :terminal_failed
            | :canceled
    @values [:pending, :running, :succeeded, :retryable_failed, :terminal_failed, :canceled]

    @spec values() :: [t()]
    def values, do: @values

    @spec default() :: t()
    def default, do: :pending

    @spec valid?(term()) :: boolean()
    def valid?(value), do: value in @values
  end

  defmodule ArtifactStatus do
    @moduledoc """
    Artifact state used by `Jidoka.Artifact`.
    """
    @type t :: :pending | :ready | :archived
    @values [:pending, :ready, :archived]

    @spec values() :: [t()]
    def values, do: @values

    @spec default() :: t()
    def default, do: :pending

    @spec valid?(term()) :: boolean()
    def valid?(value), do: value in @values
  end

  defmodule ArtifactType do
    @moduledoc """
    Initial artifact types for the MVP.
    """
    @type t ::
            :diff
            | :transcript
            | :verifier_report
            | :command_log
            | :execution_report
            | :prompt_report

    @values [
      :diff,
      :transcript,
      :verifier_report,
      :command_log,
      :execution_report,
      :prompt_report
    ]

    @spec values() :: [t()]
    def values, do: @values

    @spec valid?(term()) :: boolean()
    def valid?(value), do: value in @values
  end

  defmodule EnvironmentLeaseMode do
    @moduledoc """
    Lease modes for `Jidoka.EnvironmentLease`.
    """
    @type t :: :exclusive
    @values [:exclusive]

    @spec values() :: [t()]
    def values, do: @values

    @spec default() :: t()
    def default, do: :exclusive

    @spec valid?(term()) :: boolean()
    def valid?(value), do: value in @values
  end

  defmodule EnvironmentLeaseStatus do
    @moduledoc """
    Lease status for `Jidoka.EnvironmentLease`.
    """
    @type t :: :active | :released | :expired
    @values [:active, :released, :expired]

    @spec values() :: [t()]
    def values, do: @values

    @spec default() :: t()
    def default, do: :active

    @spec valid?(term()) :: boolean()
    def valid?(value), do: value in @values
  end

  defmodule VerificationResultStatus do
    @moduledoc """
    Verification result outcome.
    """
    @type t :: :passed | :retryable_failed | :terminal_failed
    @values [:passed, :retryable_failed, :terminal_failed]

    @spec values() :: [t()]
    def values, do: @values

    @spec default() :: t()
    def default, do: :retryable_failed

    @spec valid?(term()) :: boolean()
    def valid?(value), do: value in @values
  end

  defmodule OutcomeStatus do
    @moduledoc """
    Final durable outcome for `Jidoka.Outcome`.
    """
    @type t ::
            :pending
            | :approved
            | :retryable_failed
            | :terminal_failed
            | :canceled
    @values [:pending, :approved, :retryable_failed, :terminal_failed, :canceled]

    @spec values() :: [t()]
    def values, do: @values

    @spec default() :: t()
    def default, do: :pending

    @spec valid?(term()) :: boolean()
    def valid?(value), do: value in @values
  end

  defmodule EventType do
    @moduledoc """
    Event families emitted by the runtime.
    """
    @type t ::
            :session_opened
            | :session_closed
            | :run_submitted
            | :run_updated
            | :attempt_started
            | :attempt_completed
            | :artifact_emitted
            | :verification_completed
    @values [
      :session_opened,
      :session_closed,
      :run_submitted,
      :run_updated,
      :attempt_started,
      :attempt_completed,
      :artifact_emitted,
      :verification_completed
    ]

    @spec values() :: [t()]
    def values, do: @values

    @spec valid?(term()) :: boolean()
    def valid?(value), do: value in @values
  end

  defmodule EventStatus do
    @moduledoc """
    Storage lifecycle for `Jidoka.Event`.
    """
    @type t :: :recorded | :replayed
    @values [:recorded, :replayed]

    @spec values() :: [t()]
    def values, do: @values

    @spec default() :: t()
    def default, do: :recorded

    @spec valid?(term()) :: boolean()
    def valid?(value), do: value in @values
  end

  def validate_id(id) when is_binary(id) and byte_size(id) > 0, do: :ok
  def validate_id(_), do: {:error, :invalid_id}

  def validate_version(version) when is_integer(version) and version > 0, do: :ok
  def validate_version(_), do: {:error, :invalid_version}

  def validate_datetime(%DateTime{}), do: :ok
  def validate_datetime(_), do: {:error, :invalid_datetime}

  def now, do: DateTime.utc_now() |> DateTime.truncate(:microsecond)
end
