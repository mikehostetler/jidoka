defmodule Jidoka.TestAttemptExecutionAdapters.Success do
  @moduledoc "Stub adapter that emits progress and succeeds."

  @behaviour Jidoka.AttemptExecution

  alias Jidoka.AttemptExecution.{AttemptOutput, AttemptSpec, ProgressEvent}

  @impl true
  def execute(%AttemptSpec{} = spec) do
    progress = [
      %ProgressEvent{
        label: :prepare,
        message: "loaded task and workspace",
        metadata: %{
          attempt_id: spec.attempt_id,
          workspace_path: spec.environment_lease.workspace_path
        }
      },
      %ProgressEvent{
        label: :simulate_work,
        message: "worked for no-op adapter",
        metadata: %{adapter: :stub_success}
      }
    ]

    {:ok,
     %AttemptOutput{
       status: :succeeded,
       progress: progress,
       metadata: %{adapter: :stub_success, attempt_number: spec.attempt_number}
     }}
  end
end

defmodule Jidoka.TestAttemptExecutionAdapters.Failure do
  @moduledoc "Stub adapter that reports a hard failure."

  @behaviour Jidoka.AttemptExecution

  alias Jidoka.AttemptExecution.AttemptSpec

  @impl true
  def execute(%AttemptSpec{}) do
    {:error, %{reason: :stubbed_execution_failure}}
  end
end
