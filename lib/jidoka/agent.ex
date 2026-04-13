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

  @spec submit(session_handle(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def submit(session_handle, task, opts \\ []) when is_binary(task),
    do: SessionServer.submit(session_handle, task, opts)

  @spec snapshot(session_handle()) :: {:ok, map()} | {:error, term()}
  def snapshot(session_handle), do: SessionServer.session_snapshot(session_handle)

  @spec run_snapshot(session_handle(), String.t()) :: {:ok, map()} | {:error, term()}
  def run_snapshot(session_handle, run_id), do: SessionServer.run_snapshot(session_handle, run_id)

  @spec approve(session_handle(), String.t()) :: :ok | {:error, term()}
  def approve(session_handle, run_id), do: SessionServer.approve(session_handle, run_id)

  @spec reject(session_handle(), String.t()) :: :ok | {:error, term()}
  def reject(session_handle, run_id), do: SessionServer.reject(session_handle, run_id)

  @spec retry(session_handle(), String.t(), keyword()) :: :ok | {:error, term()}
  def retry(session_handle, run_id, opts \\ []) when is_binary(run_id),
    do: SessionServer.retry(session_handle, run_id, opts)

  @spec cancel(session_handle(), String.t()) :: :ok | {:error, term()}
  def cancel(session_handle, run_id), do: SessionServer.cancel(session_handle, run_id)
end
