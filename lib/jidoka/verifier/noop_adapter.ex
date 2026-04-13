defmodule Jidoka.Verifier.NoopAdapter do
  @moduledoc """
  Default verifier adapter used for coding tasks when no custom verifier is selected.
  """

  @behaviour Jidoka.Verifier

  alias Jidoka.Verifier
  alias Jidoka.Verifier.VerificationOutput

  @impl true
  def execute(%Verifier.VerifierSpec{} = spec) do
    {:ok,
     %VerificationOutput{
       status: :passed,
       outcome_summary: %{checks: :noop},
       metadata: %{adapter: :noop_verifier, task_pack: spec.task_pack}
     }}
  end
end
