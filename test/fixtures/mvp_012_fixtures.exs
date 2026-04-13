[
  %{
    id: "passing_task",
    description: "Passing task with an approval decision",
    task: "format a small status message helper",
    execution_adapter: Jidoka.Hardening.FixtureAdapters.SuccessExecution,
    verification_adapter: Jidoka.Hardening.FixtureAdapters.PassedVerification,
    steps: [:approve],
    expected: %{
      initial_run_status: :awaiting_approval,
      initial_outcome: nil,
      initial_verification_status: :passed,
      final_run_status: :completed,
      final_outcome: :approved,
      final_attempt_count: 1,
      final_verification_status: :passed,
      artifact_count: 0
    }
  },
  %{
    id: "retryable_verifier_failure",
    description: "Retryable verifier failure that is retried and approved",
    task: "improve retry handling with defensive checks",
    execution_adapter: Jidoka.Hardening.FixtureAdapters.SuccessExecution,
    verification_adapter: Jidoka.Hardening.FixtureAdapters.RetryableVerification,
    steps: [
      {
        :retry,
        %{
          execution_adapter: Jidoka.Hardening.FixtureAdapters.SuccessExecution,
          verification_adapter: Jidoka.Hardening.FixtureAdapters.PassedVerification
        }
      },
      :approve
    ],
    expected: %{
      initial_run_status: :failed,
      initial_outcome: :retryable_failed,
      initial_verification_status: :retryable_failed,
      final_run_status: :completed,
      final_outcome: :approved,
      final_attempt_count: 2,
      final_verification_status: :passed,
      artifact_count: 0
    }
  },
  %{
    id: "resume_oriented",
    description: "Session closed after await then resumed before approval",
    task: "prepare a resumable coding context",
    execution_adapter: Jidoka.Hardening.FixtureAdapters.SuccessExecution,
    verification_adapter: Jidoka.Hardening.FixtureAdapters.PassedVerification,
    steps: [:resume, :approve],
    expected: %{
      initial_run_status: :awaiting_approval,
      initial_outcome: nil,
      initial_verification_status: :passed,
      resume_status: :awaiting_approval,
      final_run_status: :completed,
      final_outcome: :approved,
      final_attempt_count: 1,
      final_verification_status: :passed,
      artifact_count: 0
    }
  }
]
