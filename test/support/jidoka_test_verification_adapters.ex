defmodule Jidoka.TestVerificationAdapters.Passed do
  @moduledoc "Stub verifier adapter that reports success."

  @behaviour Jidoka.Verifier

  alias Jidoka.Verifier.{VerificationOutput, VerifierSpec}

  @impl true
  def execute(%VerifierSpec{} = _spec) do
    {:ok,
     %VerificationOutput{
       status: :passed,
       outcome_summary: %{checks: [:passed]},
       metadata: %{adapter: :stub_verification_passed}
     }}
  end
end

defmodule Jidoka.TestVerificationAdapters.RetryableFailed do
  @moduledoc "Stub verifier adapter that reports a retryable failure."

  @behaviour Jidoka.Verifier

  alias Jidoka.Verifier.{VerificationOutput, VerifierSpec}

  @impl true
  def execute(%VerifierSpec{} = _spec) do
    {:ok,
     %VerificationOutput{
       status: :retryable_failed,
       outcome_summary: %{checks: [:retryable_failed]},
       metadata: %{adapter: :stub_verification_retryable_failed}
     }}
  end
end

defmodule Jidoka.TestVerificationAdapters.TerminalFailed do
  @moduledoc "Stub verifier adapter that reports a terminal failure."

  @behaviour Jidoka.Verifier

  alias Jidoka.Verifier.{VerificationOutput, VerifierSpec}

  @impl true
  def execute(%VerifierSpec{} = _spec) do
    {:ok,
     %VerificationOutput{
       status: :terminal_failed,
       outcome_summary: %{checks: [:terminal_failed]},
       metadata: %{adapter: :stub_verification_terminal_failed}
     }}
  end
end
