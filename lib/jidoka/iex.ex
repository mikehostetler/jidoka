defmodule Jidoka.IEx do
  @moduledoc """
  Thin interactive helpers for `iex -S mix`.

  This module is intentionally small and delegates to `Jidoka`, `Jidoka.Agent`,
  and `Jidoka.Bus`. It exists to make the first operator experience pleasant
  without introducing a second runtime surface.
  """

  alias Jidoka.Agent
  alias Jidoka.Bus
  alias Jidoka.Signals

  @type session_handle :: Agent.session_handle()

  @spec open(keyword()) :: {:ok, Agent.session_ref()} | {:error, term()}
  def open(opts \\ []), do: Jidoka.start_session(opts)

  @spec resume(session_handle()) :: {:ok, Agent.session_ref()} | {:error, term()}
  def resume(session), do: Jidoka.resume_session(session)

  @spec close(session_handle()) :: :ok | {:error, term()}
  def close(session), do: Jidoka.close_session(session)

  @spec ask(session_handle(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def ask(session, prompt, opts \\ []), do: Agent.ask(session, prompt, opts)

  @spec await(session_handle(), Agent.request_id() | map(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def await(session, request, opts \\ []), do: Agent.await(session, request, opts)

  @spec steer(session_handle(), String.t(), keyword()) :: :ok | {:error, term()}
  def steer(session, message, opts \\ []), do: Agent.steer(session, message, opts)

  @spec inject(session_handle(), String.t(), keyword()) :: :ok | {:error, term()}
  def inject(session, message, opts \\ []), do: Agent.inject(session, message, opts)

  @spec branch(session_handle(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def branch(session, opts \\ []), do: Agent.branch(session, opts)

  @spec goto(session_handle(), String.t(), keyword()) :: {:ok, Agent.snapshot()} | {:error, term()}
  def goto(session, branch_id, opts \\ []), do: Agent.navigate(session, branch_id, opts)

  @spec snapshot(session_handle()) :: {:ok, Agent.snapshot()} | {:error, term()}
  def snapshot(session), do: Agent.snapshot(session)

  @spec refresh_resources(session_handle(), keyword()) :: {:ok, map()} | {:error, term()}
  def refresh_resources(session, opts \\ []), do: Agent.refresh_resources(session, opts)

  @spec watch(session_handle(), keyword()) :: {:ok, term()} | {:error, term()}
  def watch(session, opts \\ []) do
    with {:ok, session_ref} <- Agent.normalize_session(session) do
      Bus.subscribe(Signals.session_event_path(session_ref), opts)
    end
  end

  @spec unwatch(term(), keyword()) :: :ok | {:error, term()}
  def unwatch(subscription_id, opts \\ []), do: Bus.unsubscribe(subscription_id, opts)

  @spec events(session_handle(), keyword()) :: {:ok, term()} | {:error, term()}
  def events(session, opts \\ []) do
    with {:ok, session_ref} <- Agent.normalize_session(session) do
      Bus.get_log(Keyword.put_new(opts, :path, Signals.session_path(session_ref)))
    end
  end

  @spec help() :: %{module: module(), workflow: [String.t()]}
  def help do
    %{
      module: __MODULE__,
      workflow: [
        "{:ok, ref} = Jidoka.IEx.open(id: \"repo-main\", cwd: File.cwd!())",
        "{:ok, sub} = Jidoka.IEx.watch(ref)",
        "{:ok, req} = Jidoka.IEx.ask(ref, \"inspect the failing tests\")",
        "{:ok, snap} = Jidoka.IEx.snapshot(ref)",
        "flush()",
        ":ok = Jidoka.IEx.unwatch(sub)",
        ":ok = Jidoka.IEx.close(ref)"
      ]
    }
  end
end
