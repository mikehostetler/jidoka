defmodule Jidoka.AttemptWorker do
  @moduledoc """
  Runtime process that executes one attempt spec through an adapter.
  """

  use GenServer

  alias Jidoka.AttemptExecution
  alias Jidoka.AttemptExecution.{AttemptOutput, AttemptSpec, ProgressEvent}
  alias Jidoka.VerificationResult
  alias Jidoka.Verifier
  alias Jidoka.Verifier.VerificationOutput
  alias Jidoka.SessionServer

  def child_spec(%AttemptSpec{} = spec) do
    %{
      id: {__MODULE__, spec.attempt_id},
      start: {__MODULE__, :start_link, [spec]},
      restart: :temporary
    }
  end

  def start_link(%AttemptSpec{} = spec) do
    GenServer.start_link(__MODULE__, spec, name: via_name(spec.attempt_id))
  end

  @spec stop(String.t()) :: :ok | {:error, :not_found}
  def stop(attempt_id) when is_binary(attempt_id) do
    case Registry.lookup(Jidoka.Registry, {:attempt, attempt_id}) do
      [] ->
        {:error, :not_found}

      [{pid, _}] ->
        ref = Process.monitor(pid)
        Process.exit(pid, :kill)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        after
          1_000 -> :ok
        end
    end
  end

  @spec via_name(String.t()) :: {:via, Registry, {module(), any()}}
  def via_name(attempt_id) when is_binary(attempt_id) do
    {:via, Registry, {Jidoka.Registry, {:attempt, attempt_id}}}
  end

  @impl true
  def init(%AttemptSpec{} = spec) do
    Process.send_after(self(), :run, 0)
    {:ok, spec}
  end

  @impl true
  def handle_info(:run, %AttemptSpec{} = spec) do
    case SessionServer.mark_attempt_running(spec.attempt_id) do
      :ok ->
        case AttemptExecution.execute(spec) do
          {:ok, %AttemptOutput{} = output} ->
            with :ok <- emit_progress_events(spec.attempt_id, output),
                 :ok <- persist_execution_result(spec.attempt_id, output),
                 :ok <- run_verification(spec, output) do
              :ok
            else
              {:error, reason} ->
                emit_failure_event(spec.attempt_id, {:error, reason})
            end

          {:error, reason} ->
            emit_failure_event(spec.attempt_id, {:error, reason})
        end

      {:error, reason} ->
        emit_failure_event(spec.attempt_id, {:error, reason})
    end

    {:stop, :normal, spec}
  end

  defp run_verification(_spec, %AttemptOutput{status: status})
       when status in [:retryable_failed, :terminal_failed], do: :ok

  defp run_verification(
         %AttemptSpec{verification_adapter: verification_adapter} = spec,
         output = %AttemptOutput{
           status: :succeeded,
           metadata: execution_metadata
         }
       ) do
    spec = %{
      spec
      | metadata: Map.put(spec.metadata, :execution_metadata, execution_metadata),
        verification_adapter: verification_adapter
    }

    with {:ok, verification_output} <- execute_verifier(spec, output),
         :ok <- persist_verification_result(spec, verification_output) do
      :ok
    else
      {:error, reason} ->
        persist_verification_error(spec, reason)
    end
  end

  defp run_verification(_spec, _output), do: :ok

  defp execute_verifier(spec, output) do
    verification_spec = %Verifier.VerifierSpec{
      session_id: spec.session_id,
      run_id: spec.run_id,
      attempt_id: spec.attempt_id,
      task: spec.task,
      attempt_number: spec.attempt_number,
      task_pack: spec.task_pack,
      environment_lease: spec.environment_lease,
      execution_output: output,
      metadata: spec.metadata,
      adapter: spec.verification_adapter
    }

    case Verifier.execute(verification_spec) do
      {:ok, %VerificationOutput{} = output} ->
        {:ok, output}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp persist_verification_result(spec, %VerificationOutput{} = output) do
    verification_result =
      VerificationResult.new(
        id: generate_id("verification"),
        attempt_id: spec.attempt_id,
        status: output.status,
        outcome_summary: output.outcome_summary,
        metadata: Map.put(output.metadata, :verification_adapter, spec.verification_adapter)
      )

    case verification_result do
      {:ok, result} ->
        SessionServer.mark_verification_completed(spec.attempt_id, result)

      {:error, reason} ->
        emit_failure_event(spec.attempt_id, {:invalid_verification_result, reason})
    end
  end

  defp persist_verification_error(spec, reason) do
    persist_verification_result(
      spec,
      %VerificationOutput{
        status: :terminal_failed,
        outcome_summary: %{error: :verification_adapter_failure},
        metadata: %{reason: reason}
      }
    )
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

  defp persist_execution_result(
         attempt_id,
         %AttemptOutput{status: :succeeded, metadata: metadata, artifacts: artifacts}
       ) do
    with :ok <- SessionServer.persist_attempt_artifacts(attempt_id, artifacts),
         :ok <- SessionServer.mark_attempt_completed(attempt_id, metadata) do
      :ok
    end
  end

  defp persist_execution_result(
         attempt_id,
         %AttemptOutput{status: status, metadata: metadata, artifacts: artifacts, error: error}
       )
       when status in [:retryable_failed, :terminal_failed] do
    with :ok <- SessionServer.persist_attempt_artifacts(attempt_id, artifacts),
         :ok <- SessionServer.mark_attempt_failed(attempt_id, status, error, metadata) do
      :ok
    end
  end

  defp persist_execution_result(attempt_id, output) do
    emit_failure_event(attempt_id, {:invalid_attempt_status, output})
  end

  defp emit_failure_event(attempt_id, reason) do
    SessionServer.mark_attempt_failed(attempt_id, :terminal_failed, reason, %{})
    :ok
  end

  defp generate_id(prefix) when is_binary(prefix) do
    "#{prefix}-" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end
end
