defmodule Jidoka.IEx do
  @moduledoc """
  Thin interactive helper over `Jidoka.Agent`.
  """

  alias Jidoka.Agent
  alias Jidoka.Bus
  alias Jidoka.SessionBusPath
  alias Jidoka.Signals

  @spec open(keyword()) :: {:ok, Agent.session_ref()} | {:error, term()}
  def open(opts \\ []), do: Agent.open(opts)

  @spec watch(Agent.session_handle()) :: {:ok, String.t()} | {:error, term()}
  def watch(session_handle) do
    with {:ok, session_ref} <- Agent.resolve_session_ref(session_handle) do
      {:ok, "watch-" <> session_ref <> "-" <> Signals.generate_id("sub")}
    end
  end

  @spec unwatch(String.t()) :: :ok
  def unwatch(_subscription_id), do: :ok

  @spec ask(Agent.session_handle(), String.t()) :: {:ok, map()} | {:error, term()}
  def ask(session_handle, prompt), do: Agent.ask(session_handle, prompt)

  @spec await(Agent.session_handle(), String.t()) :: {:ok, map()} | {:error, term()}
  def await(session_handle, request_id), do: Agent.await(session_handle, request_id)

  @spec snapshot(Agent.session_handle()) :: {:ok, map()} | {:error, term()}
  def snapshot(session_handle), do: Agent.snapshot(session_handle)

  @spec events(Agent.session_handle()) :: {:ok, [map()]} | {:error, term()}
  def events(session_handle) do
    with {:ok, session_ref} <- Agent.resolve_session_ref(session_handle) do
      Bus.get_log(path: SessionBusPath.wildcard(session_ref))
    end
  end

  @spec help() :: map()
  def help do
    %{
      module: __MODULE__,
      workflow: [:open, :watch, :ask, :await, :snapshot, :events, :unwatch]
    }
  end
end
