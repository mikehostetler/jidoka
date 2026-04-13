defmodule JidokaSessionServerTest do
  use ExUnit.Case, async: false

  alias Jidoka.Attempt
  alias Jidoka.EnvironmentLease
  alias Jidoka.Run
  alias Jidoka.SessionServer

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

  defp unique_id(prefix) do
    "#{prefix}-" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end
end
