defmodule JidokaAttemptWorkerTest do
  use ExUnit.Case, async: false

  alias Jidoka.Bus
  alias Jidoka.SessionServer
  alias Jidoka.TestAttemptExecutionAdapters.{Failure, Success}

  test "attempt worker streams progress and completion events" do
    session_id = unique_id("attempt-worker-success")
    on_exit(fn -> SessionServer.close(session_id) end)

    assert {:ok, ^session_id} =
             SessionServer.open(id: session_id, cwd: "/tmp/attempt-worker-success")

    assert {:ok, %{run: run}} =
             SessionServer.submit(
               session_id,
               "implement login form",
               execution_adapter: Success
             )

    assert :ok = await_attempt_status(session_id, run.id, :succeeded)

    {:ok, run_snapshot} = SessionServer.run_snapshot(session_id, run.id)
    assert run_snapshot.run.id == run.id

    assert run_snapshot.run.latest_attempt_id == List.last(run_snapshot.attempts).id

    latest_attempt =
      Enum.find(run_snapshot.attempts, &(&1.id == run_snapshot.run.latest_attempt_id))

    assert latest_attempt.status == :succeeded
    assert latest_attempt.started_at
    assert latest_attempt.finished_at

    {:ok, log} = Bus.get_log(path: event_path(session_id))

    attempts_events =
      Enum.filter(log, fn entry ->
        entry.signal.payload[:attempt_id] == latest_attempt.id &&
          entry.signal.type in [:attempt_started, :attempt_progress, :attempt_completed]
      end)

    event_types = Enum.map(attempts_events, & &1.signal.type)

    assert event_types == [
             :attempt_started,
             :attempt_progress,
             :attempt_progress,
             :attempt_completed
           ]

    assert hd(attempts_events).signal.payload[:status] == :running
  end

  test "attempt worker emits failure event when adapter returns error" do
    session_id = unique_id("attempt-worker-failure")
    on_exit(fn -> SessionServer.close(session_id) end)

    assert {:ok, ^session_id} =
             SessionServer.open(id: session_id, cwd: "/tmp/attempt-worker-failure")

    assert {:ok, %{run: run}} =
             SessionServer.submit(
               session_id,
               "implement flaky behavior",
               execution_adapter: Failure
             )

    assert :ok = await_attempt_status(session_id, run.id, :terminal_failed)

    {:ok, run_snapshot} = SessionServer.run_snapshot(session_id, run.id)

    latest_attempt =
      Enum.find(run_snapshot.attempts, &(&1.id == run_snapshot.run.latest_attempt_id))

    assert latest_attempt.status == :terminal_failed

    {:ok, log} = Bus.get_log(path: event_path(session_id))

    attempts_events =
      Enum.filter(log, fn entry ->
        entry.signal.payload[:attempt_id] == latest_attempt.id &&
          entry.signal.type in [:attempt_started, :attempt_failed]
      end)

    event_types = Enum.map(attempts_events, & &1.signal.type)

    assert event_types == [:attempt_started, :attempt_failed]

    assert Enum.any?(
             attempts_events,
             &(&1.signal.payload[:reason] == {:error, %{reason: :stubbed_execution_failure}})
           )
  end

  defp await_attempt_status(session_id, run_id, expected_status) do
    await_attempt_status(session_id, run_id, expected_status, 25)
  end

  defp await_attempt_status(session_id, run_id, expected_status, remaining) when remaining > 0 do
    case latest_attempt_status(session_id, run_id) do
      {:ok, status} when status == expected_status ->
        :ok

      _ ->
        Process.sleep(10)
        await_attempt_status(session_id, run_id, expected_status, remaining - 1)
    end
  end

  defp await_attempt_status(_session_id, _run_id, _expected_status, 0),
    do: :error

  defp latest_attempt_status(session_id, run_id) do
    with {:ok, run_snapshot} <- SessionServer.run_snapshot(session_id, run_id),
         latest_attempt when is_map(latest_attempt) <-
           Enum.find(run_snapshot.attempts, &(&1.id == run_snapshot.run.latest_attempt_id)) do
      {:ok, latest_attempt.status}
    else
      _ -> :error
    end
  end

  defp unique_id(prefix) do
    prefix <> "-" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end

  defp event_path(session_id) do
    "jidoka.session." <> Base.url_encode64(session_id, padding: false) <> ".events"
  end
end
