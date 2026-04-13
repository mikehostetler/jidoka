defmodule Jidoka.TuiServer do
  @moduledoc """
  Minimal TUI shell host process for attaching to sessions and consuming runtime updates.

  The shell keeps a local, derived view model and intentionally does not mutate
  durable runtime entities directly.
  """

  use GenServer

  alias Jidoka.Agent
  alias Jidoka.Bus
  alias Jidoka.TuiRenderer

  @default_poll_interval 150
  @event_history_limit 24
  @attempt_progress_history_limit 8
  @artifact_focus_types [:diff, :command_log, :verifier_report]
  @all_control_commands [:interrupt, :steer, :approve, :retry, :reject, :cancel, :reconnect]

  defmodule State do
    @moduledoc false
    defstruct [
      :mode,
      :recoverable_reason,
      :session_ref,
      :session_handle,
      :session_status,
      :active_run_id,
      :active_run_status,
      :active_attempt_id,
      :active_attempt_status,
      :active_run_task,
      :active_run_attempt_count,
      :active_attempt_number,
      :active_run_outcome,
      :active_lease_id,
      :active_lease_workspace_path,
      :event_path,
      :focused_artifacts,
      :active_verification_result,
      :command_controls,
      :activity_lines,
      :focused_progress_lines,
      :input_buffer,
      :last_event_count,
      :last_error,
      :poll_interval,
      :open_options
    ]
  end

  @type mode :: :attached | :recoverable

  @type reason :: :missing | :closed | :disconnected | :invalid_session_handle | nil | term()

  @type shell_state ::
          %State{
            mode: mode,
            recoverable_reason: reason,
            session_ref: String.t() | nil,
            session_handle: Agent.session_handle() | nil,
            session_status: atom() | nil,
            active_run_id: String.t() | nil,
            active_run_status: atom() | nil,
            active_attempt_id: String.t() | nil,
            active_attempt_status: atom() | nil,
            active_run_task: String.t() | nil,
            active_run_attempt_count: non_neg_integer(),
            active_attempt_number: non_neg_integer() | nil,
            active_run_outcome: atom() | nil,
            active_lease_id: String.t() | nil,
            active_lease_workspace_path: String.t() | nil,
            event_path: String.t() | nil,
            focused_artifacts: map(),
            active_verification_result: map() | Jidoka.VerificationResult.t() | nil,
            command_controls: map(),
            activity_lines: [String.t()],
            focused_progress_lines: [String.t()],
            input_buffer: String.t(),
            last_event_count: non_neg_integer(),
            last_error: term() | nil,
            poll_interval: pos_integer() | nil
          }

  @type control_request ::
          :interrupt | :steer | :approve | :retry | :reject | :cancel | :reconnect

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    start_opts = Keyword.take(opts, [:name])
    GenServer.start_link(__MODULE__, opts, start_opts)
  end

  @spec state(GenServer.server()) :: shell_state()
  def state(server), do: GenServer.call(server, :state)

  @spec attach(GenServer.server(), Agent.session_handle() | nil, keyword()) :: shell_state()
  def attach(server, session_handle, open_opts \\ []) do
    GenServer.call(server, {:attach, session_handle, open_opts})
  end

  @spec reconnect(GenServer.server(), Agent.session_handle()) :: :ok | {:error, term()}
  def reconnect(server, session_handle)
      when is_binary(session_handle) or is_pid(session_handle) do
    command(server, :reconnect, session_handle)
  end

  @spec command(
          GenServer.server(),
          control_request() | String.t(),
          Agent.session_handle() | String.t() | nil
        ) :: :ok | {:error, term()}
  def command(server, command, target \\ nil) do
    GenServer.call(server, {:command, command, target})
  end

  @spec render_model(GenServer.server()) :: map()
  def render_model(server), do: GenServer.call(server, :render_model)

  @spec render(GenServer.server()) :: String.t()
  def render(server), do: GenServer.call(server, :render)

  @spec refresh(GenServer.server()) :: shell_state()
  def refresh(server), do: GenServer.call(server, :refresh)

  @spec stop(GenServer.server()) :: :ok
  def stop(server), do: GenServer.stop(server, :normal)

  @impl true
  def init(opts) do
    session_handle = Keyword.get(opts, :session)
    poll_interval = Keyword.get(opts, :poll_interval, @default_poll_interval)
    open_options = Keyword.take(opts, [:id, :cwd, :workspace_path, :metadata, :status])

    state =
      %State{
        mode: :recoverable,
        recoverable_reason: :invalid_session_handle,
        session_handle: session_handle,
        session_ref: nil,
        event_path: nil,
        session_status: nil,
        active_run_id: nil,
        active_run_status: nil,
        active_attempt_id: nil,
        active_attempt_status: nil,
        active_run_task: nil,
        active_run_attempt_count: 0,
        active_attempt_number: nil,
        active_run_outcome: nil,
        active_lease_id: nil,
        active_lease_workspace_path: nil,
        focused_artifacts: default_artifact_focus(),
        command_controls: default_command_controls(:recoverable),
        active_verification_result: nil,
        activity_lines: [],
        focused_progress_lines: [],
        input_buffer: "",
        last_event_count: 0,
        last_error: nil,
        poll_interval: interval_or_nil(poll_interval),
        open_options: open_options
      }
      |> connect(session_handle, open_options)

    state =
      if should_poll?(state) do
        schedule_refresh(state)
      else
        state
      end

    {:ok, state}
  end

  @impl true
  def handle_call(:state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_call(:render_model, _from, state) do
    {:reply, TuiRenderer.render_model(state), state}
  end

  @impl true
  def handle_call(:render, _from, state) do
    {:reply, TuiRenderer.render(state), state}
  end

  @impl true
  def handle_call({:command, command_name, target}, _from, state) do
    case normalize_control(command_name) do
      {:error, reason} ->
        {:reply, {:error, reason}, mark_command_error(state, reason)}

      :reconnect ->
        case apply_reconnect(state, target) do
          {:ok, next_state} -> {:reply, :ok, next_state}
          {:error, reason, next_state} -> {:reply, {:error, reason}, next_state}
        end

      control ->
        case apply_run_command(state, control, target) do
          {:ok, next_state} -> {:reply, :ok, next_state}
          {:error, reason, next_state} -> {:reply, {:error, reason}, next_state}
        end
    end
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    refreshed = maybe_refresh(state)
    {:reply, refreshed, refreshed}
  end

  @impl true
  def handle_call({:attach, session_handle, open_opts}, _from, state) do
    open_opts =
      Keyword.merge(
        state.open_options,
        Keyword.take(open_opts, [:id, :cwd, :workspace_path, :metadata, :status])
      )

    attached = connect(%{state | open_options: open_opts}, session_handle, open_opts)
    {:reply, attached, attached}
  end

  @impl true
  def handle_info(:refresh, state) do
    refreshed = maybe_refresh(state)
    next_state = if should_poll?(refreshed), do: schedule_refresh(refreshed), else: refreshed
    {:noreply, next_state}
  end

  defp connect(state, session_handle, open_opts) do
    case ensure_session_handle(session_handle, open_opts) do
      {:ok, session_ref} ->
        state_with_handle = %{
          state
          | session_handle: session_handle,
            session_ref: session_ref,
            event_path: event_path(session_ref),
            mode: :recoverable
        }

        hydrate_from_snapshot(state_with_handle)

      {:error, :not_found} ->
        %{
          state
          | mode: :recoverable,
            recoverable_reason: :missing,
            session_ref: nil,
            event_path: nil,
            session_status: nil,
            active_run_id: nil,
            active_run_status: nil,
            active_attempt_id: nil,
            active_attempt_status: nil,
            active_run_task: nil,
            active_run_attempt_count: 0,
            active_attempt_number: nil,
            active_lease_id: nil,
            active_lease_workspace_path: nil,
            focused_artifacts: default_artifact_focus(),
            active_verification_result: nil,
            command_controls:
              default_command_controls(:recoverable, state.session_ref, session_status: nil),
            active_run_outcome: nil,
            activity_lines: [],
            focused_progress_lines: [],
            last_event_count: 0,
            last_error: :not_found
        }

      {:error, reason} ->
        %{
          state
          | mode: :recoverable,
            recoverable_reason: :invalid_session_handle,
            session_ref: nil,
            event_path: nil,
            session_status: nil,
            active_run_id: nil,
            active_run_status: nil,
            active_attempt_id: nil,
            active_attempt_status: nil,
            active_run_task: nil,
            active_run_attempt_count: 0,
            active_attempt_number: nil,
            active_lease_id: nil,
            active_lease_workspace_path: nil,
            focused_artifacts: default_artifact_focus(),
            active_verification_result: nil,
            command_controls:
              default_command_controls(:recoverable, state.session_ref, reason: reason),
            active_run_outcome: nil,
            activity_lines: [],
            focused_progress_lines: [],
            last_event_count: 0,
            last_error: reason
        }
    end
  end

  defp ensure_session_handle(nil, open_opts) do
    case Agent.open(open_opts) do
      {:ok, session_ref} -> {:ok, session_ref}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_session_handle(session_handle, _open_opts) do
    case Agent.resume(session_handle) do
      {:ok, session_ref} -> {:ok, session_ref}
      {:error, reason} -> {:error, reason}
    end
  end

  defp hydrate_from_snapshot(state) do
    with {:ok, snapshot} <- Agent.snapshot(state.session_ref),
         {:ok, log} <- Bus.get_log(path: state.event_path) do
      derive_state = derive_status(snapshot)

      {activity_lines, focused_progress_lines, last_event_count} =
        summarize_events(state, log, derive_state.active_run_id, derive_state.active_attempt_id)

      session_status = derive_state.session_status

      if session_status == :closed do
        %{
          state
          | mode: :recoverable,
            recoverable_reason: :closed,
            session_status: session_status,
            active_run_id: derive_state.active_run_id,
            active_run_status: derive_state.active_run_status,
            active_attempt_id: derive_state.active_attempt_id,
            active_attempt_status: derive_state.active_attempt_status,
            active_run_task: derive_state.active_run_task,
            active_run_attempt_count: derive_state.active_run_attempt_count,
            active_attempt_number: derive_state.active_attempt_number,
            active_run_outcome: derive_state.active_run_outcome,
            command_controls:
              derive_command_controls(
                :recoverable,
                state.session_ref,
                derive_state.active_run_status,
                derive_state.active_run_outcome,
                derive_state.active_attempt_status,
                session_status: :closed
              ),
            active_lease_id: derive_state.active_lease_id,
            active_lease_workspace_path: derive_state.active_lease_workspace_path,
            focused_artifacts: derive_state.focused_artifacts,
            active_verification_result: derive_state.active_verification_result,
            activity_lines: activity_lines,
            focused_progress_lines: focused_progress_lines,
            last_event_count: last_event_count,
            last_error: nil
        }
      else
        %{
          state
          | mode: :attached,
            recoverable_reason: nil,
            session_status: session_status,
            active_run_id: derive_state.active_run_id,
            active_run_status: derive_state.active_run_status,
            active_attempt_id: derive_state.active_attempt_id,
            active_attempt_status: derive_state.active_attempt_status,
            active_run_task: derive_state.active_run_task,
            active_run_attempt_count: derive_state.active_run_attempt_count,
            active_attempt_number: derive_state.active_attempt_number,
            active_run_outcome: derive_state.active_run_outcome,
            command_controls:
              derive_command_controls(
                :attached,
                state.session_ref,
                derive_state.active_run_status,
                derive_state.active_run_outcome,
                derive_state.active_attempt_status
              ),
            active_lease_id: derive_state.active_lease_id,
            active_lease_workspace_path: derive_state.active_lease_workspace_path,
            focused_artifacts: derive_state.focused_artifacts,
            active_verification_result: derive_state.active_verification_result,
            activity_lines: activity_lines,
            focused_progress_lines: focused_progress_lines,
            last_event_count: last_event_count,
            last_error: nil
        }
      end
    else
      {:error, :not_found} ->
        %{
          state
          | mode: :recoverable,
            recoverable_reason: :missing,
            session_status: nil,
            active_run_id: nil,
            active_run_status: nil,
            active_attempt_id: nil,
            active_attempt_status: nil,
            active_run_task: nil,
            active_run_attempt_count: 0,
            active_attempt_number: nil,
            active_lease_id: nil,
            active_lease_workspace_path: nil,
            focused_artifacts: default_artifact_focus(),
            active_verification_result: nil,
            command_controls:
              default_command_controls(:recoverable, state.session_ref, session_status: nil),
            active_run_outcome: nil,
            activity_lines: [],
            focused_progress_lines: [],
            last_event_count: 0,
            last_error: :not_found
        }

      {:error, _reason} ->
        %{
          state
          | mode: :recoverable,
            recoverable_reason: :disconnected,
            session_status: nil,
            active_run_id: nil,
            active_run_status: nil,
            active_attempt_id: nil,
            active_attempt_status: nil,
            active_run_task: nil,
            active_run_attempt_count: 0,
            active_attempt_number: nil,
            active_lease_id: nil,
            active_lease_workspace_path: nil,
            focused_artifacts: default_artifact_focus(),
            active_verification_result: nil,
            command_controls:
              default_command_controls(:recoverable, state.session_ref, session_status: nil),
            active_run_outcome: nil,
            activity_lines: [],
            focused_progress_lines: [],
            last_event_count: 0,
            last_error: :disconnected
        }
    end
  end

  defp derive_status(snapshot) do
    session = snapshot.session
    active_run = active_run(snapshot.runs, session)
    active_attempt = active_attempt(snapshot.attempts, active_run)
    active_run_attempt_count = active_attempt_count(snapshot.attempts, active_run)
    active_lease = active_lease(snapshot.leases, active_attempt)

    %{
      session_status: session.status,
      active_run_id: active_run && active_run.id,
      active_run_status: active_run && active_run.status,
      active_run_task: active_run && active_run.task,
      active_run_outcome: active_run && active_run.outcome,
      active_run_attempt_count: active_run_attempt_count,
      active_attempt_id: active_attempt && active_attempt.id,
      active_attempt_status: active_attempt && active_attempt.status,
      active_attempt_number: active_attempt && active_attempt.attempt_number,
      active_lease_id: active_lease && active_lease.id,
      active_lease_workspace_path: active_lease && active_lease.workspace_path,
      focused_artifacts:
        summarize_focus_artifacts(snapshot.artifacts, active_run, active_attempt),
      active_verification_result:
        summarize_focus_verification_result(snapshot.verification_results, active_attempt)
    }
  end

  defp active_run([], _session), do: nil

  defp active_run(runs, session) do
    if session.active_run_id in [nil, ""] do
      List.last(runs)
    else
      Enum.find(runs, fn run -> run.id == session.active_run_id end) || List.last(runs)
    end
  end

  defp active_attempt(attempts, nil), do: nil

  defp active_attempt([], _run), do: nil

  defp active_attempt(attempts, active_run) do
    if active_run.latest_attempt_id in [nil, ""] do
      List.last(attempts)
    else
      Enum.find(attempts, fn attempt -> attempt.id == active_run.latest_attempt_id end) ||
        List.last(attempts)
    end
  end

  defp active_attempt_count(_, nil), do: 0

  defp active_attempt_count(attempts, %Jidoka.Run{id: run_id}) do
    Enum.count(attempts, &(&1.run_id == run_id))
  end

  defp default_command_controls(mode, session_ref \\ nil, opts \\ []) do
    case mode do
      :recoverable ->
        derive_command_controls(:recoverable, session_ref, nil, nil, nil,
          session_status: Keyword.get(opts, :session_status)
        )

      :attached ->
        derive_command_controls(:attached, session_ref, nil, nil, nil)

      _ ->
        %{
          interrupt: :illegal,
          steer: :illegal,
          approve: :illegal,
          reject: :illegal,
          retry: :illegal,
          cancel: :illegal,
          reconnect: :illegal
        }
    end
  end

  defp derive_command_controls(:recoverable, session_ref, run_status, run_outcome, attempt_status,
         session_status: session_status
       ) do
    reconnect =
      if is_binary(session_ref) and session_status != :closed, do: :legal, else: :illegal

    %{
      interrupt: :illegal,
      steer: :illegal,
      approve: :illegal,
      reject: :illegal,
      retry: :illegal,
      cancel: :illegal,
      reconnect: reconnect
    }
  end

  defp derive_command_controls(:attached, _session_ref, run_status, run_outcome, attempt_status) do
    %{
      interrupt: command_legal?(:interrupt, run_status, run_outcome, attempt_status),
      steer: command_legal?(:steer, run_status, run_outcome, attempt_status),
      approve: command_legal?(:approve, run_status, run_outcome, attempt_status),
      reject: command_legal?(:reject, run_status, run_outcome, attempt_status),
      retry: command_legal?(:retry, run_status, run_outcome, attempt_status),
      cancel: command_legal?(:cancel, run_status, run_outcome, attempt_status),
      reconnect: :illegal
    }
  end

  defp command_legal?(:interrupt, :running, _run_outcome, :running), do: :legal
  defp command_legal?(:steer, :running, _run_outcome, :running), do: :legal
  defp command_legal?(:approve, :awaiting_approval, _outcome, :succeeded), do: :legal
  defp command_legal?(:reject, :awaiting_approval, _outcome, :succeeded), do: :legal
  defp command_legal?(:retry, :failed, :retryable_failed, :retryable_failed), do: :legal

  defp command_legal?(:cancel, :queued, _run_outcome, :pending), do: :legal
  defp command_legal?(:cancel, :queued, _run_outcome, :running), do: :legal
  defp command_legal?(:cancel, :running, _run_outcome, :pending), do: :legal
  defp command_legal?(:cancel, :running, _run_outcome, :running), do: :legal
  defp command_legal?(:cancel, :awaiting_approval, _run_outcome, _attempt_status), do: :legal
  defp command_legal?(_, _run_status, _run_outcome, _attempt_status), do: :illegal

  defp apply_run_command(state, control, target) do
    with {:ok, run_id} <- resolve_run_id(state, target),
         :ok <- ensure_attached(state),
         :ok <- ensure_command_enabled(state.command_controls, control),
         :ok <- execute_runtime_command(state, control, run_id) do
      {:ok, clear_command_error(maybe_refresh(state))}
    else
      {:error, reason} -> {:error, reason, mark_command_error(state, reason)}
    end
  end

  defp apply_reconnect(state, target) do
    case resolve_reconnect_target(state, target) do
      {:ok, session_handle} ->
        next = connect(state, session_handle, state.open_options)

        {:ok, clear_command_error(next)}

      {:error, reason} ->
        {:error, reason, mark_command_error(state, reason)}
    end
  end

  defp resolve_reconnect_target(_state, target) when is_binary(target) or is_pid(target),
    do: {:ok, target}

  defp resolve_reconnect_target(state, _target) when is_binary(state.session_ref),
    do: {:ok, state.session_ref}

  defp resolve_reconnect_target(_state, _target), do: {:error, :invalid_session_handle}

  defp resolve_run_id(state, nil) do
    case state.active_run_id do
      run_id when is_binary(run_id) -> {:ok, run_id}
      _ -> {:error, :missing_run_id}
    end
  end

  defp resolve_run_id(_state, run_id) when is_binary(run_id), do: {:ok, run_id}
  defp resolve_run_id(_state, _), do: {:error, :missing_run_id}

  defp ensure_attached(%{mode: :attached, session_ref: session_ref}) when is_binary(session_ref),
    do: :ok

  defp ensure_attached(_), do: {:error, :session_not_attached}

  defp ensure_command_enabled(command_controls, control) do
    if Map.get(command_controls, control) == :legal do
      :ok
    else
      {:error, {:command_not_allowed, control}}
    end
  end

  defp execute_runtime_command(state, :approve, run_id),
    do: Agent.approve(state.session_ref, run_id)

  defp execute_runtime_command(state, :reject, run_id),
    do: Agent.reject(state.session_ref, run_id)

  defp execute_runtime_command(state, :retry, run_id), do: Agent.retry(state.session_ref, run_id)

  defp execute_runtime_command(state, :cancel, run_id),
    do: Agent.cancel(state.session_ref, run_id)

  defp execute_runtime_command(state, :interrupt, run_id),
    do: Agent.cancel(state.session_ref, run_id)

  defp execute_runtime_command(state, :steer, run_id), do: Agent.cancel(state.session_ref, run_id)

  defp normalize_control(action) when is_atom(action) do
    if action in @all_control_commands do
      action
    else
      {:error, :unknown_control}
    end
  end

  defp normalize_control("interrupt"), do: :interrupt
  defp normalize_control("steer"), do: :steer
  defp normalize_control("approve"), do: :approve
  defp normalize_control("retry"), do: :retry
  defp normalize_control("reject"), do: :reject
  defp normalize_control("cancel"), do: :cancel
  defp normalize_control("reconnect"), do: :reconnect
  defp normalize_control(_), do: {:error, :unknown_control}

  defp clear_command_error(state), do: %{state | last_error: nil}
  defp mark_command_error(state, reason), do: %{state | last_error: reason}

  defp default_artifact_focus do
    %{diff: [], command_log: [], verifier_report: []}
  end

  defp summarize_focus_artifacts(_artifacts, nil, _active_attempt), do: default_artifact_focus()
  defp summarize_focus_artifacts(_artifacts, nil, nil), do: default_artifact_focus()

  defp summarize_focus_artifacts(artifacts, active_run, active_attempt) do
    run_id = active_run && active_run.id
    attempt_id = active_attempt && active_attempt.id

    relevant =
      Enum.filter(artifacts, fn artifact ->
        (is_binary(run_id) && artifact.run_id == run_id) or
          (is_binary(attempt_id) && artifact.attempt_id == attempt_id)
      end)

    for type <- @artifact_focus_types, into: %{} do
      entries =
        relevant
        |> Enum.filter(fn artifact -> artifact.type == type end)
        |> Enum.sort_by(
          fn artifact ->
            artifact.updated_at || artifact.created_at
          end,
          {:desc, DateTime}
        )

      {type, entries}
    end
  end

  defp summarize_focus_verification_result(_results, nil), do: nil

  defp summarize_focus_verification_result(results, active_attempt) do
    attempt_id = active_attempt && active_attempt.id

    results
    |> Enum.filter(fn result ->
      result.attempt_id == attempt_id and is_binary(result.attempt_id)
    end)
    |> Enum.sort_by(
      fn result ->
        result.updated_at || result.created_at
      end,
      {:desc, DateTime}
    )
    |> List.first()
  end

  defp active_lease(_leases, nil), do: nil

  defp active_lease(leasings, %Jidoka.Attempt{id: attempt_id}) do
    Enum.find(leasings, fn lease -> lease.attempt_id == attempt_id end)
  end

  defp summarize_events(state, log, active_run_id, active_attempt_id) do
    total = length(log)

    same_focus =
      state.active_run_id == active_run_id and state.active_attempt_id == active_attempt_id

    start = if same_focus, do: min(state.last_event_count, total), else: 0
    new_events = Enum.drop(log, start)
    previous_activity_lines = if same_focus, do: state.activity_lines, else: []
    previous_progress_lines = if same_focus, do: state.focused_progress_lines, else: []

    focused_events =
      new_events
      |> Enum.filter(&event_for_active_run?(&1, active_run_id, active_attempt_id))
      |> Enum.map(&format_event_line/1)

    focused_progress_events =
      new_events
      |> Enum.filter(&attempt_progress_for_active_attempt?(&1, active_attempt_id))
      |> Enum.map(&format_event_line/1)

    updated_activity_lines =
      previous_activity_lines
      |> Enum.concat(focused_events)
      |> Enum.take(-@event_history_limit)

    updated_progress_lines =
      previous_progress_lines
      |> Enum.concat(focused_progress_events)
      |> Enum.take(-@attempt_progress_history_limit)

    {updated_activity_lines, updated_progress_lines, total}
  end

  defp format_event_line(%{signal: signal}) when is_map(signal) do
    payload = Map.get(signal, :payload, %{})
    type = Map.get(signal, :type, :unknown)
    run_id = Map.get(payload, :run_id, "<none>")
    attempt_id = Map.get(payload, :attempt_id, "<none>")
    details = event_line_details(type, payload)

    [
      "event=#{type}",
      "run=#{run_id}",
      "attempt=#{attempt_id}",
      details
    ]
    |> Enum.filter(&(&1 != nil))
    |> Enum.filter(&(&1 != ""))
    |> Enum.join(" ")
  end

  defp format_event_line(_), do: "event=unknown"

  defp event_line_details(:attempt_progress, payload) when is_map(payload) do
    label = Map.get(payload, :label, "unknown")
    message = Map.get(payload, :message, "")
    status = Map.get(payload, :status, :none)

    cond do
      is_binary(message) and byte_size(message) > 0 ->
        "label=#{label} message=#{message} status=#{status}"

      true ->
        "label=#{label} status=#{status}"
    end
  end

  defp event_line_details(_, payload) when is_map(payload) do
    status = Map.get(payload, :status)
    operation = Map.get(payload, :operation)
    reason = Map.get(payload, :reason)
    verification_status = Map.get(payload, :verification_status)

    [
      status,
      operation,
      reason,
      verification_status
    ]
    |> Enum.with_index()
    |> Enum.reduce([], fn {value, index}, parts ->
      case {index, value} do
        {0, nil} -> parts
        {0, _} -> [~s(status=#{inspect(value)}) | parts]
        {1, nil} -> parts
        {1, _} -> [~s(operation=#{inspect(value)}) | parts]
        {2, nil} -> parts
        {2, _} -> [~s(reason=#{inspect(value)}) | parts]
        {3, nil} -> parts
        {3, _} -> [~s(verification=#{inspect(value)}) | parts]
        _ -> parts
      end
    end)
    |> Enum.reverse()
    |> Enum.join(" ")
  end

  defp event_line_details(_, _), do: nil

  defp event_for_active_run?(%{signal: signal}, active_run_id, active_attempt_id) do
    payload = Map.get(signal, :payload, %{})
    type = Map.get(signal, :type, :unknown)
    run_id = Map.get(payload, :run_id)
    attempt_id = Map.get(payload, :attempt_id)

    cond do
      is_nil(active_run_id) ->
        type in [:session_opened, :session_closed]

      is_binary(run_id) and run_id == active_run_id ->
        true

      is_binary(active_attempt_id) and is_binary(attempt_id) and attempt_id == active_attempt_id ->
        true

      true ->
        false
    end
  end

  defp event_for_active_run?(_entry, _active_run_id, _active_attempt_id), do: false

  defp attempt_progress_for_active_attempt?(%{signal: signal}, active_attempt_id) do
    payload = Map.get(signal, :payload, %{})
    event_type = Map.get(signal, :type, nil)
    attempt_id = Map.get(payload, :attempt_id)

    is_binary(active_attempt_id) and event_type == :attempt_progress and
      attempt_id == active_attempt_id
  end

  defp attempt_progress_for_active_attempt?(_entry, _active_attempt_id), do: false

  defp maybe_refresh(%{mode: :attached, session_ref: session_ref, event_path: event_path} = state)
       when is_binary(session_ref) and is_binary(event_path) do
    hydrate_from_snapshot(state)
  end

  defp maybe_refresh(%{mode: :recoverable} = state) do
    with {:ok, snapshot} <- Agent.snapshot(state.session_ref),
         {:ok, log} <- Bus.get_log(path: state.event_path) do
      # allow operator to retry attach if the target is now healthy.
      if snapshot.session.status == :closed do
        state
      else
        hydrate_from_snapshot(%{state | mode: :attached, recoverable_reason: nil})
      end
    else
      _ -> state
    end
  end

  defp schedule_refresh(state) do
    Process.send_after(self(), :refresh, state.poll_interval || @default_poll_interval)
    state
  end

  defp should_poll?(%{mode: :attached, poll_interval: interval})
       when is_integer(interval) and interval > 0,
       do: true

  defp should_poll?(_), do: false

  defp interval_or_nil(value) when is_integer(value) and value > 0, do: value
  defp interval_or_nil(_), do: nil

  defp event_path(session_id) when is_binary(session_id),
    do: "jidoka.session." <> Base.url_encode64(session_id, padding: false) <> ".events"

  defp event_path(_), do: nil
end
