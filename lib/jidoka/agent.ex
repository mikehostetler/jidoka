defmodule Jidoka.Agent do
  @moduledoc """
  Compatibility facade for session lifecycle operations.
  """

  alias Jidoka.SessionServer

  @type session_ref :: SessionServer.session_id()
  @type session_handle :: SessionServer.session_handle()

  @spec open(keyword()) :: {:ok, session_ref()} | {:error, term()}
  def open(opts \\ []), do: SessionServer.open(opts)

  @spec resume(session_handle()) :: {:ok, session_ref()} | {:error, term()}
  def resume(session_handle), do: SessionServer.resume(session_handle)

  @spec lookup(session_handle()) ::
          {:ok, %{session_ref: session_ref(), pid: pid()}} | {:error, term()}
  def lookup(session_handle), do: SessionServer.lookup(session_handle)

  @spec close(session_handle()) :: :ok | {:error, term()}
  def close(session_handle), do: SessionServer.close(session_handle)

  @spec snapshot(session_handle()) :: {:ok, map()} | {:error, term()}
  def snapshot(session_handle), do: SessionServer.session_snapshot(session_handle)

  @spec run_snapshot(session_handle(), String.t()) :: {:ok, map()} | {:error, term()}
  def run_snapshot(session_handle, run_id), do: SessionServer.run_snapshot(session_handle, run_id)
end
