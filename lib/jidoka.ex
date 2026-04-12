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
end
