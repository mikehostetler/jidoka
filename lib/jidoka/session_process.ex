defmodule Jidoka.SessionProcess do
  @moduledoc """
  Runtime process for one resumed/open session.

  Session processes are intentionally thin in ST-MVP-003.
  """

  use GenServer

  def child_spec(session_id) when is_binary(session_id) do
    %{
      id: {__MODULE__, session_id},
      start: {__MODULE__, :start_link, [session_id]},
      restart: :temporary
    }
  end

  def start_link(session_id) when is_binary(session_id) do
    GenServer.start_link(__MODULE__, session_id, name: via_name(session_id))
  end

  def via_name(session_id) do
    {:via, Registry, {Jidoka.Registry, {:session, session_id}}}
  end

  @impl true
  def init(session_id) do
    {:ok, %{session_id: session_id}}
  end
end
