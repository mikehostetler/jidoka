defmodule Jidoka.Agent do
  @moduledoc """
  Compatibility facade for session lifecycle operations.
  """

  alias Jidoka.AgentState
  alias Jidoka.Bus
  alias Jidoka.SessionBusPath
  alias Jidoka.SessionServer
  alias Jidoka.Signals

  @type session_ref :: SessionServer.session_id()
  @type session_handle :: SessionServer.session_handle()

  @spec open(keyword()) :: {:ok, session_ref()} | {:error, term()}
  def open(opts \\ []) do
    with {:ok, session_ref} <- SessionServer.open(opts) do
      AgentState.ensure(session_ref, opts)
      :ok = Bus.clear_log(path: event_path(session_ref))
      {:ok, session_ref}
    end
  end

  @spec resume(session_handle()) :: {:ok, session_ref()} | {:error, term()}
  def resume(session_handle) do
    with {:ok, session_ref} <- SessionServer.resume(session_handle) do
      AgentState.ensure(session_ref)
      {:ok, session_ref}
    end
  end

  @spec lookup(session_handle()) ::
          {:ok, %{session_ref: session_ref(), pid: pid()}} | {:error, term()}
  def lookup(session_handle), do: SessionServer.lookup(session_handle)

  @spec close(session_handle()) :: :ok | {:error, term()}
  def close(session_handle), do: SessionServer.close(session_handle)

  @spec ask(session_handle(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def ask(session_handle, prompt, _opts \\ []) when is_binary(prompt) do
    with {:ok, session_ref} <- resolve_session_ref(session_handle) do
      request_id = Signals.generate_id("request")
      correlation_id = Signals.generate_id("corr")

      request = %{
        id: request_id,
        prompt: prompt,
        correlation_id: correlation_id,
        status: :completed
      }

      emit_ask_signals(session_ref, request, prompt)

      AgentState.update(session_ref, fn state ->
        state
        |> put_in([:requests, request_id], request)
        |> update_in([:transcript], &(&1 ++ [%{id: request_id, content: prompt}]))
        |> update_metadata()
      end)

      {:ok, request}
    end
  end

  @spec await(session_handle(), String.t()) :: {:ok, map()} | {:error, term()}
  def await(session_handle, request_id) when is_binary(request_id) do
    with {:ok, session_ref} <- resolve_session_ref(session_handle),
         {:ok, state} <- AgentState.get(session_ref),
         {:ok, request} <- fetch_request(state, request_id) do
      {:ok, request}
    end
  end

  @spec branch(session_handle(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def branch(session_handle, opts \\ []) do
    with {:ok, session_ref} <- resolve_session_ref(session_handle) do
      branch_id = Signals.generate_id("branch")

      AgentState.update(session_ref, fn state ->
        label = Keyword.get(opts, :label, branch_id)

        state
        |> put_in([:branches, branch_id], %{id: branch_id, label: label})
        |> update_in([:branch_order], &(&1 ++ [branch_id]))
        |> Map.put(:current_leaf, branch_id)
      end)

      {:ok, branch_id}
    end
  end

  @spec navigate(session_handle(), String.t()) :: {:ok, map()} | {:error, term()}
  def navigate(session_handle, branch_id) when is_binary(branch_id) do
    with {:ok, session_ref} <- resolve_session_ref(session_handle),
         {:ok, state} <- AgentState.get(session_ref),
         true <- Map.has_key?(state.branches, branch_id) || {:error, :not_found} do
      AgentState.update(session_ref, fn current ->
        current
        |> Map.put(:current_branch, branch_id)
        |> Map.put(:current_leaf, branch_id)
      end)

      snapshot(session_ref)
    end
  end

  @spec submit(session_handle(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def submit(session_handle, task, opts \\ []) when is_binary(task),
    do: SessionServer.submit(session_handle, task, opts)

  @spec snapshot(session_handle()) :: {:ok, map()} | {:error, term()}
  def snapshot(session_handle) do
    with {:ok, session_ref} <- resolve_session_ref(session_handle),
         {:ok, session_snapshot} <- SessionServer.session_snapshot(session_ref) do
      state = AgentState.ensure(session_ref)
      {:ok, compatibility_snapshot(session_ref, session_snapshot, state)}
    end
  end

  @spec run_snapshot(session_handle(), String.t()) :: {:ok, map()} | {:error, term()}
  def run_snapshot(session_handle, run_id), do: SessionServer.run_snapshot(session_handle, run_id)

  @spec refresh_resources(session_handle()) :: {:ok, map()} | {:error, term()}
  def refresh_resources(session_handle) do
    with {:ok, session_ref} <- resolve_session_ref(session_handle),
         {:ok, resources} <- refresh_agent_resources(session_ref) do
      {:ok, resources}
    end
  end

  @spec approve(session_handle(), String.t()) :: :ok | {:error, term()}
  def approve(session_handle, run_id), do: SessionServer.approve(session_handle, run_id)

  @spec reject(session_handle(), String.t()) :: :ok | {:error, term()}
  def reject(session_handle, run_id), do: SessionServer.reject(session_handle, run_id)

  @spec retry(session_handle(), String.t(), keyword()) :: :ok | {:error, term()}
  def retry(session_handle, run_id, opts \\ []) when is_binary(run_id),
    do: SessionServer.retry(session_handle, run_id, opts)

  @spec cancel(session_handle(), String.t()) :: :ok | {:error, term()}
  def cancel(session_handle, run_id), do: SessionServer.cancel(session_handle, run_id)

  @spec resolve_session_ref(session_handle()) :: {:ok, session_ref()} | {:error, term()}
  def resolve_session_ref(session_handle) when is_binary(session_handle),
    do: {:ok, session_handle}

  def resolve_session_ref(session_handle) when is_pid(session_handle) do
    case SessionServer.lookup(session_handle) do
      {:ok, %{session_ref: session_ref}} -> {:ok, session_ref}
      {:error, reason} -> {:error, reason}
    end
  end

  def resolve_session_ref(_session_handle), do: {:error, :invalid_session_handle}

  defp fetch_request(state, request_id) do
    case Map.fetch(state.requests, request_id) do
      {:ok, request} -> {:ok, request}
      :error -> {:error, :not_found}
    end
  end

  defp emit_ask_signals(session_ref, request, prompt) do
    command_signal = %{
      type: "jidoka.command.ask",
      subject: session_ref,
      data: %{
        input: prompt,
        request_id: request.id,
        meta: %{correlation_id: request.correlation_id}
      }
    }

    completion_signal = %{
      type: "jidoka.event.request.completed",
      subject: session_ref,
      data: %{
        request_id: request.id,
        meta: %{correlation_id: request.correlation_id}
      }
    }

    :ok = Bus.record(command_signal, SessionBusPath.events(session_ref))
    :ok = Bus.record(completion_signal, SessionBusPath.events(session_ref))
  end

  defp compatibility_snapshot(session_ref, session_snapshot, state) do
    session_map =
      session_snapshot.session
      |> Map.from_struct()
      |> Map.put(:ref, session_ref)

    current_run =
      Enum.find(session_snapshot.runs, &(&1.id == session_snapshot.session.active_run_id)) ||
        List.last(session_snapshot.runs)

    metadata = Map.put(state.metadata || %{}, :thread_length, length(state.transcript))

    session_snapshot
    |> Map.put(:session, session_map)
    |> Map.put(:run, current_run)
    |> Map.put(:branch, %{
      current: state.current_branch,
      current_leaf: state.current_leaf,
      order: state.branch_order
    })
    |> Map.put(:transcript, state.transcript)
    |> Map.put(:tool_activity, [])
    |> Map.put(:resources, state.resources)
    |> Map.put(:metadata, metadata)
  end

  defp update_metadata(state) do
    Map.put(state, :metadata, %{thread_length: length(state.transcript)})
  end

  defp refresh_agent_resources(session_ref) do
    case AgentState.refresh_resources(session_ref) do
      {:ok, resources} -> {:ok, resources}
      :error -> {:error, :not_found}
    end
  end

  defp event_path(session_ref) do
    SessionBusPath.events(session_ref)
  end
end
