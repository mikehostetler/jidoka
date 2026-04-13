defmodule Jidoka.AttemptExecution.NoopAdapter do
  @moduledoc """
  Default stub execution adapter for MVP.

  It returns a successful attempt output and emits simple progress events that
  demonstrate lease usage.
  """

  @behaviour Jidoka.AttemptExecution

  alias Jidoka.AttemptExecution
  alias Jidoka.AttemptExecution.{AttemptOutput, AttemptSpec, ProgressEvent}

  @impl true
  def execute(%AttemptSpec{} = spec) do
    progress = [
      %ProgressEvent{
        label: :workspace_bootstrap,
        message: "using exclusive workspace",
        metadata: %{workspace_path: spec.environment_lease.workspace_path}
      }
    ]

    {:ok,
     %AttemptOutput{
       status: :succeeded,
       progress: progress,
       metadata: %{adapter: :noop, attempt_id: spec.attempt_id}
     }}
  end
end
