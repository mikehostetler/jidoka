defmodule JidokaSessionServerTest do
  use ExUnit.Case, async: false

  alias Jidoka.Attempt
  alias Jidoka.EnvironmentLease
  alias Jidoka.Run
  alias Jidoka.SessionServer

  defmodule CancelSlowAdapter do
    @moduledoc false
    @behaviour Jidoka.AttemptExecution

    alias Jidoka.AttemptExecution.{AttemptOutput, AttemptSpec}

    @impl true
    def execute(%AttemptSpec{} = _spec) do
      Process.sleep(100)

      {:ok,
       %AttemptOutput{
         status: :succeeded,
         metadata: %{adapter: :cancel_slow},
         artifacts: []
       }}
    end
  end

  test "OTP boot tree includes session, attempt and event bus processes" do
    assert is_pid(Process.whereis(Jidoka.Registry))
    assert is_pid(Process.whereis(Jidoka.SessionSupervisor))
    assert is_pid(Process.whereis(Jidoka.AttemptSupervisor))
    assert is_pid(Process.whereis(Jidoka.Bus))
    assert is_pid(Process.whereis(Jidoka.SessionServer))
  end

  test "open bootstraps a durable session and provides session lookup" do
    session_id = unique_id("session-open")
    assert {:ok, ^session_id} = SessionServer.open(id: session_id, cwd: "/tmp/session-open")

    assert {:ok, %{session_ref: ^session_id, pid: session_pid}} = SessionServer.lookup(session_id)
    assert is_pid(session_pid)

    assert {:ok, %{session_ref: ^session_id, pid: ^session_pid}} =
             SessionServer.lookup(session_pid)

    assert {:ok, session_snapshot} = SessionServer.session_snapshot(session_id)
    assert session_snapshot.session.id == session_id
    assert is_list(session_snapshot.runs)

    assert :ok = SessionServer.close(session_id)
  end

  test "resume rebuilds session process state without changing durable identifiers" do
    session_id = unique_id("session-resume")
    assert {:ok, ^session_id} = SessionServer.open(id: session_id, cwd: "/tmp/session-resume")
    assert {:ok, %{pid: original_pid}} = SessionServer.lookup(session_id)

    assert {:ok, run} =
             Run.new(id: unique_id("run"), session_id: session_id, task: "resume run")

    assert :ok = SessionServer.persist_run(run)

    assert {:ok, attempt} =
             Attempt.new(id: unique_id("attempt"), run_id: run.id, attempt_number: 1)

    assert :ok = SessionServer.persist_attempt(attempt)

    assert {:ok, lease} =
             EnvironmentLease.new(
               id: unique_id("lease"),
               attempt_id: attempt.id,
               status: :active,
               workspace_path: "/tmp/resume-leased"
             )

    assert :ok = SessionServer.persist_environment_lease(lease)

    assert :ok = SessionServer.close(session_id)

    assert {:ok, ^session_id} = SessionServer.resume(session_id)
    assert {:ok, %{pid: resumed_pid}} = SessionServer.lookup(session_id)
    assert resumed_pid != original_pid

    assert {:ok, session_snapshot} = SessionServer.session_snapshot(session_id)
    assert session_snapshot.session.id == session_id
    assert Enum.any?(session_snapshot.runs, &(&1.id == run.id))

    assert {:ok, run_snapshot} = SessionServer.run_snapshot(session_id, run.id)
    assert run_snapshot.run.id == run.id
    assert Enum.any?(run_snapshot.attempts, &(&1.id == attempt.id))
    assert Enum.any?(run_snapshot.leases, &(&1.id == lease.id))

    assert :ok = SessionServer.close(session_id)
  end

  test "submit creates durable run, initial attempt, and writable lease for the attempt" do
    session_id = unique_id("session-submit")
    assert {:ok, ^session_id} = SessionServer.open(id: session_id, cwd: "/tmp/session-submit")

    assert {:ok, %{run: run, attempt: attempt, lease: lease}} =
             SessionServer.submit(
               session_id,
               "implement login flow",
               task_pack: :coding
             )

    assert run.session_id == session_id
    assert run.task == "implement login flow"
    assert run.task_pack == :coding
    assert run.status == :queued
    assert attempt.run_id == run.id
    assert attempt.status == :pending
    assert attempt.attempt_number == 1
    assert lease.attempt_id == attempt.id
    assert lease.status == :active
    assert lease.mode == :exclusive
    assert lease.workspace_path =~ run.id
    assert lease.workspace_path =~ attempt.id
    assert lease.metadata.run_id == run.id
    assert lease.metadata.source_workspace_path == "/tmp/session-submit"

    assert {:ok, session_snapshot} = SessionServer.session_snapshot(session_id)
    assert Enum.find(session_snapshot.runs, &(&1.id == run.id))

    assert session_snapshot.runs
           |> Enum.find(&(&1.id == run.id))
           |> Map.get(:latest_attempt_id) == attempt.id

    assert Enum.find(session_snapshot.attempts, &(&1.id == attempt.id))

    assert %{
             status: status
           } = Enum.find(session_snapshot.attempts, &(&1.id == attempt.id))

    assert status in [
             :pending,
             :running,
             :succeeded,
             :retryable_failed,
             :terminal_failed
           ]

    assert Enum.find(session_snapshot.leases, &(&1.id == lease.id))

    assert Enum.find(session_snapshot.leases, &(&1.id == lease.id)).workspace_path ==
             lease.workspace_path

    assert {:ok, run_snapshot} = SessionServer.run_snapshot(session_id, run.id)
    assert run_snapshot.run.id == run.id
    assert run_snapshot.run.latest_attempt_id == attempt.id
    assert Enum.any?(run_snapshot.attempts, &(&1.id == attempt.id))
    assert Enum.any?(run_snapshot.leases, &(&1.id == lease.id))
    assert Enum.any?(run_snapshot.events, &(&1.event.type == :run_submitted))

    assert :ok = SessionServer.close(session_id)
  end

  test "approve finalizes run outcome and seals accepted artifact set" do
    session_id = unique_id("session-approve")
    assert {:ok, ^session_id} = SessionServer.open(id: session_id, cwd: "/tmp/session-approve")

    assert {:ok, %{run: run}} =
             SessionServer.submit(
               session_id,
               "approve pending run",
               execution_adapter: Jidoka.TestAttemptExecutionAdapters.Success,
               verification_adapter: Jidoka.TestVerificationAdapters.Passed
             )

    assert :ok = await_run_status(session_id, run.id, :awaiting_approval)
    {:ok, pre_snapshot} = SessionServer.run_snapshot(session_id, run.id)
    pre_attempt = latest_attempt(pre_snapshot)

    assert :ok = SessionServer.approve(session_id, run.id)

    {:ok, snapshot} = SessionServer.run_snapshot(session_id, run.id)
    latest = latest_attempt(snapshot)

    assert snapshot.run.status == :completed
    assert snapshot.run.outcome == :approved
    assert latest.status == :succeeded
    assert snapshot.run.artifact_ids == latest.artifact_ids

    assert Enum.any?(
             snapshot.outcomes,
             &(&1.outcome == :approved and &1.attempt_id == snapshot.run.latest_attempt_id)
           )

    assert {:error, {:invalid_run_status_for_action, :approve, :awaiting_approval, :completed}} =
             SessionServer.approve(session_id, run.id)
  end

  test "reject records terminal outcome without mutating latest attempt artifact ids" do
    session_id = unique_id("session-reject")
    assert {:ok, ^session_id} = SessionServer.open(id: session_id, cwd: "/tmp/session-reject")

    assert {:ok, %{run: run}} =
             SessionServer.submit(
               session_id,
               "reject run",
               execution_adapter: Jidoka.TestAttemptExecutionAdapters.Success,
               verification_adapter: Jidoka.TestVerificationAdapters.Passed
             )

    assert :ok = await_run_status(session_id, run.id, :awaiting_approval)
    {:ok, pre_snapshot} = SessionServer.run_snapshot(session_id, run.id)
    pre_attempt = latest_attempt(pre_snapshot)
    pre_artifact_ids = pre_attempt.artifact_ids

    assert :ok = SessionServer.reject(session_id, run.id)
    {:ok, snapshot} = SessionServer.run_snapshot(session_id, run.id)
    latest = latest_attempt(snapshot)

    assert snapshot.run.status == :failed
    assert snapshot.run.outcome == :terminal_failed
    assert latest.status == :succeeded
    assert latest.artifact_ids == pre_artifact_ids

    assert Enum.any?(
             snapshot.outcomes,
             &(&1.outcome == :terminal_failed and
                 &1.attempt_id == snapshot.run.latest_attempt_id)
           )
  end

  test "retry creates new attempt and fresh isolated environment lease" do
    session_id = unique_id("session-retry")
    assert {:ok, ^session_id} = SessionServer.open(id: session_id, cwd: "/tmp/session-retry")

    assert {:ok, %{run: run}} =
             SessionServer.submit(
               session_id,
               "retry run",
               execution_adapter: Jidoka.TestAttemptExecutionAdapters.Success,
               verification_adapter: Jidoka.TestVerificationAdapters.RetryableFailed
             )

    assert :ok = await_run_status(session_id, run.id, :failed)

    {:ok, pre_retry_snapshot} = SessionServer.run_snapshot(session_id, run.id)
    pre_attempt = latest_attempt(pre_retry_snapshot)
    pre_lease = Enum.find(pre_retry_snapshot.leases, &(&1.attempt_id == pre_attempt.id))
    assert pre_lease
    assert pre_attempt.status == :succeeded

    assert :ok = SessionServer.retry(session_id, run.id)

    assert :ok = await_run_status(session_id, run.id, :awaiting_approval)

    {:ok, retry_snapshot} = SessionServer.run_snapshot(session_id, run.id)
    retry_attempt = latest_attempt(retry_snapshot)
    retry_lease = Enum.find(retry_snapshot.leases, &(&1.attempt_id == retry_attempt.id))

    assert retry_attempt.attempt_number == 2
    assert retry_attempt.id != pre_attempt.id
    assert retry_lease.attempt_id == retry_attempt.id
    assert retry_attempt.status == :succeeded
    assert retry_snapshot.run.status == :awaiting_approval
    assert retry_snapshot.run.outcome == nil
    assert retry_lease.id != pre_lease.id
    assert retry_lease.workspace_path != pre_lease.workspace_path
    assert retry_lease.workspace_path =~ run.id
    assert retry_lease.workspace_path =~ retry_attempt.id
  end

  test "cancel stops running attempt and persists canceled run and attempt outcomes" do
    session_id = unique_id("session-cancel")
    assert {:ok, ^session_id} = SessionServer.open(id: session_id, cwd: "/tmp/session-cancel")

    assert {:ok, %{run: run}} =
             SessionServer.submit(
               session_id,
               "cancel in-flight",
               execution_adapter: CancelSlowAdapter
             )

    assert :ok = await_attempt_status(session_id, run.id, :running)
    assert :ok = SessionServer.cancel(session_id, run.id)
    assert :ok = await_run_status(session_id, run.id, :canceled)

    {:ok, snapshot} = SessionServer.run_snapshot(session_id, run.id)
    latest = latest_attempt(snapshot)

    assert snapshot.run.status == :canceled
    assert snapshot.run.outcome == :canceled
    assert latest.status == :canceled
    assert latest.metadata.cancellation_reason == :operator
    assert Enum.any?(snapshot.outcomes, &(&1.outcome == :canceled and &1.attempt_id == latest.id))
  end

  test "operator transitions reject illegal action attempts" do
    session_id = unique_id("session-transitions")

    assert {:ok, ^session_id} =
             SessionServer.open(id: session_id, cwd: "/tmp/session-transitions")

    assert {:ok, %{run: run}} = SessionServer.submit(session_id, "legal check run")

    assert {:error, {:invalid_run_status_for_action, :approve, :awaiting_approval, _}} =
             SessionServer.approve(session_id, run.id)

    assert {:error, {:invalid_run_status_for_action, :reject, :awaiting_approval, _}} =
             SessionServer.reject(session_id, run.id)

    assert {:error, {:invalid_run_status_for_action, :retry, :failed, _}} =
             SessionServer.retry(session_id, run.id)
  end

  defp unique_id(prefix) do
    "#{prefix}-" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end

  defp await_attempt_status(session_id, run_id, expected_status) do
    await_attempt_status(session_id, run_id, expected_status, 25)
  end

  defp await_attempt_status(_session_id, _run_id, _expected_status, 0), do: :error

  defp await_attempt_status(session_id, run_id, expected_status, remaining) do
    case latest_attempt_status(session_id, run_id) do
      {:ok, status} when status == expected_status ->
        :ok

      _ ->
        Process.sleep(10)
        await_attempt_status(session_id, run_id, expected_status, remaining - 1)
    end
  end

  defp await_run_status(session_id, run_id, expected_status) do
    await_run_status(session_id, run_id, expected_status, 25)
  end

  defp await_run_status(_session_id, _run_id, _expected_status, 0), do: :error

  defp await_run_status(session_id, run_id, expected_status, remaining) do
    case latest_run_status(session_id, run_id) do
      {:ok, status} when status == expected_status ->
        :ok

      _ ->
        Process.sleep(10)
        await_run_status(session_id, run_id, expected_status, remaining - 1)
    end
  end

  defp latest_attempt_status(session_id, run_id) do
    with {:ok, run_snapshot} <- SessionServer.run_snapshot(session_id, run_id),
         latest_attempt when is_map(latest_attempt) <-
           Enum.find(run_snapshot.attempts, &(&1.id == run_snapshot.run.latest_attempt_id)) do
      {:ok, latest_attempt.status}
    else
      _ -> :error
    end
  end

  defp latest_run_status(session_id, run_id) do
    with {:ok, run_snapshot} <- SessionServer.run_snapshot(session_id, run_id) do
      {:ok, run_snapshot.run.status}
    else
      _ -> :error
    end
  end

  defp latest_attempt(run_snapshot) do
    Enum.find(run_snapshot.attempts, &(&1.id == run_snapshot.run.latest_attempt_id))
  end
end
