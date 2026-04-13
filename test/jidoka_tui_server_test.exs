defmodule Jidoka.TuiServerTest do
  use ExUnit.Case, async: false

  alias Jidoka.Agent
  alias Jidoka.TestAttemptExecutionAdapters.Success
  alias Jidoka.TuiServer

  test "booted shell opens a new session and renders stable regions" do
    {:ok, pid} = TuiServer.start_link(poll_interval: 0)
    on_exit(fn -> safe_stop_tui(pid) end)

    state = TuiServer.state(pid)
    render = TuiServer.render(pid)
    model = TuiServer.render_model(pid)

    assert state.mode == :attached
    assert is_binary(state.session_ref)
    assert is_list(state.activity_lines)
    assert is_list(state.focused_progress_lines)
    assert Map.has_key?(model, :status)
    assert Map.has_key?(model, :focused_run)
    assert Map.has_key?(model, :events)
    assert Map.has_key?(model, :input)
    assert String.contains?(render, "[status]")
    assert String.contains?(render, "[focused run]")
    assert String.contains?(render, "[event stream]")
    assert String.contains?(render, "[operator input]")

    on_exit(fn -> close_session(state.session_ref) end)
  end

  test "can attach to an existing session and load an initial snapshot" do
    session_id = unique_id("tui-existing")
    assert {:ok, ^session_id} = Agent.open(id: session_id, cwd: "/tmp/tui-existing")
    on_exit(fn -> close_session(session_id) end)

    {:ok, pid} = TuiServer.start_link(session: session_id, poll_interval: 0)
    on_exit(fn -> safe_stop_tui(pid) end)

    state = TuiServer.state(pid)

    assert state.mode == :attached
    assert state.session_ref == session_id
    assert state.session_status == :initializing
  end

  test "missing sessions produce a recoverable shell state" do
    missing_session = unique_id("tui-missing")
    {:ok, pid} = TuiServer.start_link(session: missing_session, poll_interval: 0)
    on_exit(fn -> safe_stop_tui(pid) end)

    state = TuiServer.state(pid)
    render = TuiServer.render(pid)

    assert state.mode == :recoverable
    assert state.recoverable_reason == :missing
    assert String.contains?(render, "recoverable")
  end

  test "closed sessions render in a recoverable state" do
    session_id = unique_id("tui-closed")
    assert {:ok, ^session_id} = Agent.open(id: session_id, cwd: "/tmp/tui-closed")
    on_exit(fn -> close_session(session_id) end)

    assert :ok = Agent.close(session_id)

    {:ok, pid} = TuiServer.start_link(session: session_id, poll_interval: 0)
    on_exit(fn -> safe_stop_tui(pid) end)

    state = TuiServer.state(pid)

    assert state.mode == :recoverable
    assert state.recoverable_reason == :closed
    assert state.session_status == :closed
    assert state.session_ref == session_id
  end

  test "subscribes to session events and updates the view model from snapshots" do
    session_id = unique_id("tui-events")
    assert {:ok, ^session_id} = Agent.open(id: session_id, cwd: "/tmp/tui-events")
    on_exit(fn -> close_session(session_id) end)

    {:ok, pid} = TuiServer.start_link(session: session_id, poll_interval: 0)
    on_exit(fn -> safe_stop_tui(pid) end)

    assert {:ok, %{run: run, attempt: attempt}} =
             Agent.submit(session_id, "tui event smoke", execution_adapter: Success)

    assert :ok =
             await_session_activity_contains(pid, fn state ->
               state.mode == :attached &&
                 state.active_run_id == run.id &&
                 Enum.any?(state.activity_lines, &String.contains?(&1, "run_submitted")) &&
                 Enum.any?(
                   state.focused_progress_lines,
                   &String.contains?(&1, "attempt_progress")
                 ) &&
                 not is_nil(state.session_ref)
             end)

    state = TuiServer.state(pid)
    model = TuiServer.render_model(pid)

    assert state.active_run_status in [:queued, :running, :awaiting_approval]
    assert model.focused_run.heading == "focused run"
    assert Enum.any?(model.focused_run.lines, &String.contains?(&1, "run_id=#{run.id}"))
    assert Enum.any?(model.focused_run.lines, &String.contains?(&1, "attempt_id=#{attempt.id}"))
    assert Enum.any?(model.events.lines, &String.contains?(&1, "attempt_progress"))
  end

  defp await_session_activity_contains(pid, fun) do
    await_session_activity_contains(pid, fun, 50)
  end

  defp await_session_activity_contains(_pid, _fun, 0),
    do: flunk("did not receive expected TUI state")

  defp await_session_activity_contains(pid, fun, attempts_left) when attempts_left > 0 do
    TuiServer.refresh(pid)

    state = TuiServer.state(pid)

    if fun.(state) do
      :ok
    else
      Process.sleep(20)
      await_session_activity_contains(pid, fun, attempts_left - 1)
    end
  end

  defp close_session(session_id) do
    case Agent.close(session_id) do
      :ok -> :ok
      {:error, :not_found} -> :ok
      _ -> :ok
    end
  end

  defp safe_stop_tui(pid) do
    if Process.alive?(pid) do
      TuiServer.stop(pid)
    end
  end

  defp unique_id(prefix) do
    "#{prefix}-" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end
end
