defmodule Jidoka.AttemptWorker do
  @moduledoc """
  Runtime process that executes one attempt spec through an adapter.
  """

  use GenServer

  alias Jidoka.AttemptExecution
  alias Jidoka.AttemptExecution.{AttemptOutput, AttemptSpec, ProgressEvent}
  alias Jidoka.SessionServer

  def start_link(%AttemptSpec{} = spec) do
    GenServer.start_link(__MODULE__, spec)
  end

  @impl true
  def init(%AttemptSpec{} = spec) do
    Process.send_after(self(), :run, 0)
    {:ok, spec}
  end

  @impl true
  def handle_info(:run, %AttemptSpec{} = spec) do
    with :ok <- SessionServer.mark_attempt_running(spec.attempt_id),
         {:ok, output} <- AttemptExecution.execute(spec),
         :ok <- emit_progress_events(spec.attempt_id, output),
         :ok <- persist_execution_result(spec.attempt_id, output) do
      :ok
    else
      {:ok, invalid_output} ->
        emit_failure_event(spec.attempt_id, %{
          error: {:invalid_adapter_output, inspect(invalid_output)}
        })

      {:error, reason} ->
        emit_failure_event(spec.attempt_id, reason)

      _ ->
        emit_failure_event(spec.attempt_id, :unexpected_worker_error)
    end

    {:stop, :normal, spec}
  end

  defp emit_progress_events(attempt_id, %AttemptOutput{progress: progress}) do
    emit_progress_events(attempt_id, progress)
  end

  defp emit_progress_events(_attempt_id, []), do: :ok

  defp emit_progress_events(attempt_id, [%ProgressEvent{} = progress | rest]) do
    payload = %{
      label: progress.label,
      message: progress.message,
      metadata: progress.metadata
    }

    :ok = SessionServer.mark_attempt_progress(attempt_id, payload)
    emit_progress_events(attempt_id, rest)
  end

  defp emit_progress_events(_attempt_id, _progress), do: :ok

  defp persist_execution_result(attempt_id, %AttemptOutput{status: :succeeded, metadata: metadata}) do
    SessionServer.mark_attempt_completed(attempt_id, metadata)
  end

  defp persist_execution_result(
         attempt_id,
         %AttemptOutput{status: status, metadata: metadata, error: error}
       )
       when status in [:retryable_failed, :terminal_failed] do
    SessionServer.mark_attempt_failed(attempt_id, status, error, metadata)
  end

  defp persist_execution_result(attempt_id, output) do
    emit_failure_event(attempt_id, {:invalid_attempt_status, output})
  end

  defp emit_failure_event(attempt_id, reason) do
    SessionServer.mark_attempt_failed(attempt_id, :terminal_failed, reason, %{})
    :ok
  end
end
