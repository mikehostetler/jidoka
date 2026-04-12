defmodule Jidoka.Runtime do
  @moduledoc false

  use GenServer

  alias Jido.Signal
  alias Jidoka.Bus
  alias Jidoka.Persistence
  alias Jidoka.Resources.Loader
  alias Jidoka.Signals

  defmodule State do
    @moduledoc false

    defstruct [
      :session_ref,
      :status,
      :cwd,
      :home,
      :metadata,
      :branches,
      :current_branch,
      :requests,
      :last_request_id,
      :thread,
      :resources,
      :tool_activity
    ]
  end

  @spec open(keyword()) :: {:ok, String.t()} | {:error, term()}
  def open(opts \\ []) do
    session_ref = Keyword.get_lazy(opts, :id, fn -> Signals.generate_id("session") end)

    with {:error, :not_found} <- lookup(session_ref),
         {:ok, state} <- initialize_state(session_ref, opts),
         :ok <- Persistence.save(session_ref, persisted_state(state)),
         {:ok, _pid} <- start_runtime(state) do
      emit_lifecycle_event(state, "opened", %{status: "open"})
      {:ok, session_ref}
    else
      {:ok, %{session_ref: ^session_ref}} -> {:error, {:already_started, session_ref}}
      other -> other
    end
  end

  @spec resume(String.t() | pid()) :: {:ok, String.t()} | {:error, term()}
  def resume(session) do
    with {:ok, session_ref} <- normalize_lookup(session),
         {:error, :not_found} <- lookup(session_ref),
         {:ok, persisted} <- Persistence.load(session_ref),
         {:ok, _pid} <- start_runtime(state_from_persisted(persisted)) do
      emit_lifecycle_event(state_from_persisted(persisted), "resumed", %{status: "open"})
      {:ok, session_ref}
    else
      {:ok, %{session_ref: session_ref}} -> {:ok, session_ref}
      other -> other
    end
  end

  @spec lookup(String.t() | pid()) :: {:ok, %{session_ref: String.t(), pid: pid()}} | {:error, term()}
  def lookup(session) do
    with {:ok, session_ref} <- normalize_lookup(session) do
      case Registry.lookup(Jidoka.RuntimeRegistry, session_ref) do
        [{pid, _value}] when is_pid(pid) ->
          if Process.alive?(pid) do
            {:ok, %{session_ref: session_ref, pid: pid}}
          else
            {:error, :not_found}
          end

        [] -> {:error, :not_found}
      end
    end
  end

  @spec close(String.t()) :: :ok | {:error, term()}
  def close(session_ref) do
    with {:ok, %{pid: pid}} <- lookup(session_ref) do
      monitor = Process.monitor(pid)
      result = GenServer.call(pid, :close)

      receive do
        {:DOWN, ^monitor, :process, ^pid, _reason} -> result
      after
        1_000 ->
          Process.demonitor(monitor, [:flush])
          result
      end
    end
  end

  @spec dispatch(String.t(), Signal.t()) :: {:ok, term()} | {:error, term()}
  def dispatch(session_ref, %Signal{} = signal) do
    with {:ok, %{pid: pid}} <- lookup(session_ref) do
      GenServer.call(pid, {:dispatch, signal})
    end
  end

  @spec snapshot(String.t()) :: {:ok, map()} | {:error, term()}
  def snapshot(session_ref) do
    with {:ok, %{pid: pid}} <- lookup(session_ref) do
      GenServer.call(pid, :snapshot)
    end
  end

  @spec session_ref(pid()) :: {:ok, String.t()} | {:error, term()}
  def session_ref(pid) when is_pid(pid) do
    GenServer.call(pid, :session_ref)
  catch
    :exit, _reason -> {:error, :not_found}
  end

  def child_spec(state) do
    %{
      id: {__MODULE__, state.session_ref},
      start: {__MODULE__, :start_link, [state]},
      restart: :temporary
    }
  end

  def start_link(%State{} = state) do
    GenServer.start_link(__MODULE__, state, name: via_tuple(state.session_ref))
  end

  @impl true
  def init(%State{} = state) do
    {:ok, %{state | status: "open"}}
  end

  @impl true
  def handle_call(:session_ref, _from, state) do
    {:reply, {:ok, state.session_ref}, state}
  end

  @impl true
  def handle_call(:snapshot, _from, state) do
    {:reply, {:ok, snapshot_for(state)}, state}
  end

  @impl true
  def handle_call(:close, _from, state) do
    persisted = persisted_state(%{state | status: "closed"})
    :ok = Persistence.save(state.session_ref, persisted)
    emit_lifecycle_event(%{state | status: "closed"}, "closed", %{status: "closed"})
    {:stop, :normal, :ok, %{state | status: "closed"}}
  end

  @impl true
  def handle_call({:dispatch, %Signal{} = signal}, _from, state) do
    case apply_command(signal, state) do
      {:ok, result, next_state, event_name, event_data} ->
        :ok = Persistence.save(next_state.session_ref, persisted_state(next_state))
        emit_event(signal, next_state, event_name, event_data)
        {:reply, {:ok, result}, next_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp apply_command(signal, state) do
    case signal.data.action do
      "ask" -> handle_ask(signal, state)
      "await" -> handle_await(signal, state)
      "steer" -> handle_control_message(signal, state, "steer")
      "inject" -> handle_control_message(signal, state, signal.data.role || "system")
      "branch" -> handle_branch(signal, state)
      "navigate" -> handle_navigate(signal, state)
      "refresh_resources" -> handle_refresh_resources(signal, state)
      action -> {:error, {:unsupported_action, action}}
    end
  end

  defp handle_ask(signal, state) do
    request = %{
      id: signal.data.request_id,
      prompt: signal.data.prompt,
      status: "completed",
      branch_id: state.current_branch,
      correlation_id: signal.data.meta.correlation_id,
      result: %{accepted: true},
      inserted_at: now()
    }

    next_state =
      state
      |> append_thread_entry(%{
        kind: "message",
        role: "user",
        content: signal.data.prompt,
        branch_id: state.current_branch,
        correlation_id: request.correlation_id
      })
      |> put_in([Access.key!(:requests), request.id], request)
      |> Map.put(:last_request_id, request.id)
      |> touch()

    {:ok, request, next_state, "request.completed", %{request: request}}
  end

  defp handle_await(signal, state) do
    case Map.fetch(state.requests, signal.data.request_id) do
      {:ok, request} ->
        {:ok, request, touch(state), "request.awaited", %{request: request}}

      :error ->
        {:error, {:unknown_request, signal.data.request_id}}
    end
  end

  defp handle_control_message(signal, state, role) do
    next_state =
      state
      |> append_thread_entry(%{
        kind: "message",
        role: role,
        content: signal.data.message,
        branch_id: state.current_branch,
        correlation_id: signal.data.meta.correlation_id
      })
      |> touch()

    {:ok, :ok, next_state, "message.recorded", %{role: role, content: signal.data.message}}
  end

  defp handle_branch(signal, state) do
    branch_id = signal.data.branch_id || Signals.generate_id("branch")
    label = signal.data.label || branch_id

    if Map.has_key?(state.branches, branch_id) do
      {:error, {:branch_exists, branch_id}}
    else
      branch = %{
        id: branch_id,
        label: label,
        parent_id: state.current_branch,
        fork_index: length(state.thread),
        created_at: now()
      }

      next_state =
        state
        |> put_in([Access.key!(:branches), branch_id], branch)
        |> touch()

      {:ok, branch_id, next_state, "branch.created", %{branch: branch}}
    end
  end

  defp handle_navigate(signal, state) do
    branch_id = signal.data.branch_id

    if Map.has_key?(state.branches, branch_id) do
      next_state =
        state
        |> Map.put(:current_branch, branch_id)
        |> touch()

      {:ok, snapshot_for(next_state), next_state, "branch.navigated", %{branch_id: branch_id}}
    else
      {:error, {:unknown_branch, branch_id}}
    end
  end

  defp handle_refresh_resources(_signal, state) do
    next_resources = Loader.refresh(state.resources, cwd: state.cwd, home: state.home)

    next_state =
      state
      |> Map.put(:resources, next_resources)
      |> touch()

    {:ok, next_resources, next_state, "resources.refreshed", %{resources: resource_info(next_resources)}}
  end

  defp append_thread_entry(state, attrs) do
    entry =
      attrs
      |> Map.put_new(:id, Signals.generate_id("entry"))
      |> Map.put(:index, length(state.thread) + 1)
      |> Map.put_new(:inserted_at, now())

    update_in(state.thread, &(&1 ++ [entry]))
  end

  defp snapshot_for(state) do
    %{
      session: %{
        ref: state.session_ref,
        status: state.status,
        cwd: state.cwd
      },
      branch: %{
        current: state.current_branch,
        current_leaf: state.current_branch,
        branches: state.branches
      },
      run: %{
        last_request_id: state.last_request_id,
        requests: state.requests
      },
      transcript: project_transcript(state),
      tool_activity: state.tool_activity,
      resources: resource_info(state.resources),
      metadata: %{
        opened_at: state.metadata.opened_at,
        updated_at: state.metadata.updated_at,
        thread_length: length(state.thread)
      }
    }
  end

  defp project_transcript(state) do
    branch_lineage = lineage(state.current_branch, state.branches)

    state.thread
    |> Enum.filter(fn entry ->
      entry.kind == "message" and visible_on_branch?(entry, state.current_branch, branch_lineage, state.branches)
    end)
    |> Enum.map(fn entry ->
      %{
        id: entry.id,
        role: entry.role,
        content: entry.content,
        branch_id: entry.branch_id,
        inserted_at: entry.inserted_at
      }
    end)
  end

  defp visible_on_branch?(entry, current_branch, lineage, branches) do
    cond do
      entry.branch_id == current_branch ->
        true

      entry.branch_id in lineage ->
        child = branches[current_branch]
        entry.index <= child.fork_index

      true ->
        false
    end
  end

  defp lineage(branch_id, branches) do
    branch_id
    |> Stream.unfold(fn
      nil -> nil
      id -> {id, branches[id] && branches[id].parent_id}
    end)
    |> Enum.to_list()
  end

  defp resource_info(resources) do
    %{
      epoch: resources.epoch,
      version: resources.version,
      manifest: Enum.map(resources.manifest, &Map.take(&1, [:scope, :kind, :path, :digest]))
    }
  end

  defp persisted_state(state) do
    %{
      session_ref: state.session_ref,
      status: state.status,
      cwd: state.cwd,
      home: state.home,
      metadata: state.metadata,
      branches: state.branches,
      current_branch: state.current_branch,
      requests: state.requests,
      last_request_id: state.last_request_id,
      thread: state.thread,
      resources: state.resources,
      tool_activity: state.tool_activity
    }
  end

  defp state_from_persisted(persisted) do
    struct!(State, persisted)
  end

  defp initialize_state(session_ref, opts) do
    cwd = Keyword.get_lazy(opts, :cwd, &File.cwd!/0)
    home = Keyword.get(opts, :home, Loader.default_home())
    now = now()

    branches = %{
      "main" => %{
        id: "main",
        label: "main",
        parent_id: nil,
        fork_index: 0,
        created_at: now
      }
    }

    {:ok,
     %State{
       session_ref: session_ref,
       status: "open",
       cwd: cwd,
       home: home,
       metadata: %{opened_at: now, updated_at: now},
       branches: branches,
       current_branch: "main",
       requests: %{},
       last_request_id: nil,
       thread: [],
       resources: Loader.load(cwd: cwd, home: home),
       tool_activity: %{active: [], recent: []}
     }}
  end

  defp touch(state) do
    put_in(state.metadata.updated_at, now())
  end

  defp now do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  defp via_tuple(session_ref) do
    {:via, Registry, {Jidoka.RuntimeRegistry, session_ref}}
  end

  defp start_runtime(state) do
    DynamicSupervisor.start_child(Jidoka.RuntimeSupervisor, {__MODULE__, state})
  end

  defp normalize_lookup(pid) when is_pid(pid), do: session_ref(pid)
  defp normalize_lookup(session_ref) when is_binary(session_ref), do: {:ok, session_ref}
  defp normalize_lookup(other), do: {:error, {:invalid_session_handle, other}}

  defp emit_lifecycle_event(state, name, data) do
    signal = Signals.event(state.session_ref, name, data)
    _ = Bus.publish(signal)
    :ok
  end

  defp emit_event(command_signal, state, event_name, data) do
    signal =
      Signals.event(state.session_ref, event_name, data, %{
        correlation_id: command_signal.data.meta.correlation_id,
        causation_id: command_signal.id
      })

    _ = Bus.publish(signal)
    :ok
  end
end
