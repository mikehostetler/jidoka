defmodule Jidoka.AgentTest do
  use ExUnit.Case, async: false

  alias Jidoka.Agent
  alias Jidoka.IEx, as: JidokaIEx
  alias Jidoka.Persistence
  alias Jidoka.Signals

  setup do
    session_ref = Signals.generate_id("test_session")

    on_exit(fn ->
      case Jidoka.lookup_session(session_ref) do
        {:ok, _session} -> :ok = Jidoka.close_session(session_ref)
        {:error, :not_found} -> :ok
      end

      :ok = Persistence.delete(session_ref)
    end)

    %{session_ref: session_ref}
  end

  test "Jidoka.Agent is the primary runtime API and Jidoka stays lifecycle-oriented", %{
    session_ref: session_ref
  } do
    assert {:module, Jidoka.Agent} = Code.ensure_loaded(Jidoka.Agent)
    assert {:module, Jidoka} = Code.ensure_loaded(Jidoka)

    assert function_exported?(Jidoka.Agent, :open, 1)
    assert function_exported?(Jidoka.Agent, :ask, 3)
    assert function_exported?(Jidoka.Agent, :snapshot, 1)

    assert function_exported?(Jidoka, :start_session, 1)
    assert function_exported?(Jidoka, :resume_session, 1)
    assert function_exported?(Jidoka, :lookup_session, 1)
    assert function_exported?(Jidoka, :close_session, 1)

    refute function_exported?(Jidoka, :ask, 2)
    refute Code.ensure_loaded?(Jidoka.SessionAgent)

    assert {:ok, ^session_ref} = Jidoka.start_session(id: session_ref, cwd: File.cwd!())
    assert {:ok, %{session_ref: ^session_ref, pid: pid}} = Jidoka.lookup_session(session_ref)
    assert is_pid(pid)
  end

  test "ask wrappers emit canonical command and event signals with shared correlation ids", %{
    session_ref: session_ref
  } do
    assert {:ok, ^session_ref} = Agent.open(id: session_ref, cwd: File.cwd!())
    assert {:ok, %{pid: pid}} = Jidoka.lookup_session(session_ref)

    assert {:ok, request_a} = Agent.ask(session_ref, "inspect repo")
    assert {:ok, request_b} = Agent.ask(pid, "inspect repo again")

    {:ok, recorded} = Jidoka.Bus.get_log(path: session_path(session_ref))

    commands =
      recorded
      |> Enum.map(& &1.signal)
      |> Enum.filter(&String.contains?(&1.type, ".command.ask"))

    events =
      recorded
      |> Enum.map(& &1.signal)
      |> Enum.filter(&String.contains?(&1.type, ".event.request.completed"))

    assert length(commands) == 2
    assert length(events) == 2
    assert Enum.all?(commands, &(&1.subject == session_ref))
    assert Enum.all?(events, &(&1.subject == session_ref))

    command_correlation_ids = Enum.map(commands, & &1.data.meta.correlation_id) |> MapSet.new()
    event_correlation_ids = Enum.map(events, & &1.data.meta.correlation_id) |> MapSet.new()

    assert command_correlation_ids == event_correlation_ids
    assert MapSet.size(command_correlation_ids) == 2
    assert request_a.id != request_b.id
  end

  test "snapshot exposes a stable adapter read model", %{session_ref: session_ref} do
    assert {:ok, ^session_ref} = Agent.open(id: session_ref, cwd: File.cwd!())
    assert {:ok, _request} = Agent.ask(session_ref, "hello from main")
    assert {:ok, branch_id} = Agent.branch(session_ref, label: "before-refactor")
    assert {:ok, snapshot} = Agent.navigate(session_ref, branch_id)

    assert Map.has_key?(snapshot, :session)
    assert Map.has_key?(snapshot, :branch)
    assert Map.has_key?(snapshot, :run)
    assert Map.has_key?(snapshot, :transcript)
    assert Map.has_key?(snapshot, :tool_activity)
    assert Map.has_key?(snapshot, :resources)
    assert Map.has_key?(snapshot, :metadata)

    assert snapshot.branch.current == branch_id
    assert snapshot.branch.current_leaf == branch_id
    assert [%{content: "hello from main"}] = snapshot.transcript
    assert snapshot.resources.epoch == 1
  end

  test "resume keeps pinned resource state until explicit refresh", %{session_ref: session_ref} do
    cwd = temp_dir("cwd")
    home = temp_dir("home")
    File.write!(Path.join(cwd, "AGENTS.md"), "project v1")
    File.write!(Path.join(home, "config.toml"), "home = 1")

    assert {:ok, ^session_ref} = Agent.open(id: session_ref, cwd: cwd, home: home)
    {:ok, before_close} = Agent.snapshot(session_ref)

    File.write!(Path.join(cwd, "AGENTS.md"), "project v2")
    :ok = Agent.close(session_ref)

    assert {:ok, ^session_ref} = Agent.resume(session_ref)
    {:ok, resumed} = Agent.snapshot(session_ref)

    assert resumed.resources.epoch == before_close.resources.epoch
    assert resumed.resources.version == before_close.resources.version

    assert {:ok, refreshed} = Agent.refresh_resources(session_ref)
    {:ok, after_refresh} = Agent.snapshot(session_ref)

    assert refreshed.epoch == 2
    assert after_refresh.resources.epoch == 2
    assert after_refresh.resources.version != before_close.resources.version
  end

  test "resume rehydrates branch and audit metadata from persistence", %{session_ref: session_ref} do
    assert {:ok, ^session_ref} = Agent.open(id: session_ref, cwd: File.cwd!())
    assert {:ok, _request} = Agent.ask(session_ref, "persist me")
    assert {:ok, branch_id} = Agent.branch(session_ref, label: "saved-branch")
    assert {:ok, _snapshot} = Agent.navigate(session_ref, branch_id)

    {:ok, before_close} = Agent.snapshot(session_ref)
    :ok = Agent.close(session_ref)

    assert {:ok, ^session_ref} = Agent.resume(session_ref)
    {:ok, after_resume} = Agent.snapshot(session_ref)

    assert after_resume.branch.current == branch_id
    assert after_resume.metadata.thread_length == before_close.metadata.thread_length
    assert after_resume.transcript == before_close.transcript
  end

  test "repo docs no longer present Jidoka.SessionAgent as a public surface" do
    for path <- ["README.md", "PLAN.md"] do
      refute File.read!(path) =~ "Jidoka.SessionAgent"
    end
  end

  test "IEx helper stays thin and works against the same runtime surface", %{session_ref: session_ref} do
    assert {:ok, ^session_ref} = JidokaIEx.open(id: session_ref, cwd: File.cwd!())
    assert {:ok, subscription_id} = JidokaIEx.watch(session_ref)
    assert {:ok, request} = JidokaIEx.ask(session_ref, "inspect from iex")
    assert {:ok, _awaited} = JidokaIEx.await(session_ref, request.id)
    assert {:ok, snapshot} = JidokaIEx.snapshot(session_ref)
    assert {:ok, events} = JidokaIEx.events(session_ref)
    assert :ok = JidokaIEx.unwatch(subscription_id)

    assert snapshot.session.ref == session_ref

    assert Enum.any?(events, fn recorded ->
             String.contains?(recorded.signal.type, ".command.ask")
           end)

    assert Enum.any?(events, fn recorded ->
             String.contains?(recorded.signal.type, ".event.request.completed")
           end)

    help = JidokaIEx.help()
    assert help.module == Jidoka.IEx
    assert is_list(help.workflow)
  end

  defp session_path(session_ref) do
    "jidoka.session.#{Base.url_encode64(session_ref, padding: false)}.**"
  end

  defp temp_dir(prefix) do
    path = Path.join(System.tmp_dir!(), Signals.generate_id(prefix))
    File.mkdir_p!(path)
    path
  end
end
