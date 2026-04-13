defmodule Jidoka.Hardening.FixtureAdapters.SuccessExecution do
  @moduledoc "Deterministic execution adapter for MVP evaluation pass flows."

  @behaviour Jidoka.AttemptExecution

  alias Jidoka.AttemptExecution.{AttemptOutput, AttemptSpec, ProgressEvent}

  @impl true
  def execute(%AttemptSpec{} = spec) do
    progress = [
      %ProgressEvent{
        label: :fixture_execution,
        message: "executing fixture scenario",
        metadata: %{
          attempt_id: spec.attempt_id,
          workspace_path: spec.environment_lease.workspace_path
        }
      },
      %ProgressEvent{
        label: :fixture_verification_ready,
        message: "execution completed",
        metadata: %{run_id: spec.run_id, task: spec.task}
      }
    ]

    {:ok,
     %AttemptOutput{
       status: :succeeded,
       progress: progress,
       metadata: %{
         adapter: :fixture_success,
         attempt_id: spec.attempt_id,
         attempt_number: spec.attempt_number
       }
     }}
  end
end

defmodule Jidoka.Hardening.FixtureAdapters.PassedVerification do
  @moduledoc "Deterministic verifier adapter that reports passing verification."

  @behaviour Jidoka.Verifier

  alias Jidoka.Verifier.{VerificationOutput, VerifierSpec}

  @impl true
  def execute(%VerifierSpec{} = _spec) do
    {:ok,
     %VerificationOutput{
       status: :passed,
       outcome_summary: %{checks: [:passed], source: :hardening_fixture},
       metadata: %{adapter: :fixture_passed}
     }}
  end
end

defmodule Jidoka.Hardening.FixtureAdapters.RetryableVerification do
  @moduledoc "Deterministic verifier adapter that reports retryable failure."

  @behaviour Jidoka.Verifier

  alias Jidoka.Verifier.{VerificationOutput, VerifierSpec}

  @impl true
  def execute(%VerifierSpec{} = _spec) do
    {:ok,
     %VerificationOutput{
       status: :retryable_failed,
       outcome_summary: %{checks: [:retryable_failed], source: :hardening_fixture},
       metadata: %{adapter: :fixture_retryable}
     }}
  end
end
