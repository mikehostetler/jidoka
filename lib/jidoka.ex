defmodule Jidoka do
  @moduledoc """
  Small convenience facade for session lifecycle operations.

  The primary runtime API lives on `Jidoka.Agent`.
  """

  alias Jidoka.Agent

  @type session_ref :: Agent.session_ref()
  @type session_handle :: Agent.session_handle()

  @spec start_session(keyword()) :: {:ok, session_ref()} | {:error, term()}
  def start_session(opts \\ []), do: Agent.open(opts)

  @spec resume_session(session_handle()) :: {:ok, session_ref()} | {:error, term()}
  def resume_session(session), do: Agent.resume(session)

  @spec lookup_session(session_handle()) ::
          {:ok, %{session_ref: session_ref(), pid: pid()}} | {:error, term()}
  def lookup_session(session), do: Agent.lookup(session)

  @spec close_session(session_handle()) :: :ok | {:error, term()}
  def close_session(session), do: Agent.close(session)

  @spec snapshot_session(session_handle()) :: {:ok, map()} | {:error, term()}
  def snapshot_session(session), do: Agent.snapshot(session)

  @spec run_snapshot(session_handle(), String.t()) :: {:ok, map()} | {:error, term()}
  def run_snapshot(session, run_id), do: Agent.run_snapshot(session, run_id)

  @spec approve(session_handle(), String.t()) :: :ok | {:error, term()}
  def approve(session, run_id), do: Agent.approve(session, run_id)

  @spec reject(session_handle(), String.t()) :: :ok | {:error, term()}
  def reject(session, run_id), do: Agent.reject(session, run_id)

  @spec retry(session_handle(), String.t(), keyword()) :: :ok | {:error, term()}
  def retry(session, run_id, opts \\ []) when is_binary(run_id),
    do: Agent.retry(session, run_id, opts)

  @spec cancel(session_handle(), String.t()) :: :ok | {:error, term()}
  def cancel(session, run_id), do: Agent.cancel(session, run_id)
end
