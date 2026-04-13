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
      :event_path,
      :activity_lines,
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
            event_path: String.t() | nil,
            activity_lines: [String.t()],
            input_buffer: String.t(),
            last_event_count: non_neg_integer(),
            last_error: term() | nil,
            poll_interval: pos_integer() | nil
          }

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
        activity_lines: [],
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
            activity_lines: [],
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
            activity_lines: [],
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
      {activity_lines, last_event_count} = summarize_events(state, log)

      derive_state = derive_status(snapshot)
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
            activity_lines: activity_lines,
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
            activity_lines: activity_lines,
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
            activity_lines: [],
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
            activity_lines: [],
            last_event_count: 0,
            last_error: :disconnected
        }
    end
  end

  defp derive_status(snapshot) do
    session = snapshot.session
    active_run = active_run(snapshot.runs, session)
    active_attempt = active_attempt(snapshot.attempts, active_run)

    %{
      session_status: session.status,
      active_run_id: active_run && active_run.id,
      active_run_status: active_run && active_run.status,
      active_attempt_id: active_attempt && active_attempt.id,
      active_attempt_status: active_attempt && active_attempt.status
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

  defp summarize_events(state, log) do
    total = length(log)
    start = min(state.last_event_count, total)
    new_events = Enum.drop(log, start)
    lines = Enum.map(new_events, &format_event_line/1)

    updated =
      state.activity_lines
      |> Enum.concat(lines)
      |> Enum.take(-@event_history_limit)

    {updated, total}
  end

  defp format_event_line(%{signal: signal}) when is_map(signal) do
    payload = Map.get(signal, :payload, %{})
    type = Map.get(signal, :type, :unknown)
    "event=#{type} payload=#{inspect(payload)}"
  end

  defp format_event_line(_), do: "event=unknown"

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
