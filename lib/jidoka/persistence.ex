defmodule Jidoka.Persistence do
  @moduledoc """
  Persistence boundary for Jidoka session state.
  """

  @type session_ref :: String.t()
  @type persisted_state :: map()

  @callback load(session_ref()) :: {:ok, persisted_state()} | {:error, term()}
  @callback save(session_ref(), persisted_state()) :: :ok | {:error, term()}
  @callback delete(session_ref()) :: :ok | {:error, term()}
  @callback list() :: {:ok, [session_ref()]} | {:error, term()}

  @spec adapter() :: module()
  def adapter do
    Application.get_env(:jidoka, :persistence_adapter, Jidoka.Persistence.Memory)
  end

  @spec load(session_ref()) :: {:ok, persisted_state()} | {:error, term()}
  def load(session_ref), do: adapter().load(session_ref)

  @spec save(session_ref(), persisted_state()) :: :ok | {:error, term()}
  def save(session_ref, state), do: adapter().save(session_ref, state)

  @spec delete(session_ref()) :: :ok | {:error, term()}
  def delete(session_ref), do: adapter().delete(session_ref)

  @spec list() :: {:ok, [session_ref()]} | {:error, term()}
  def list, do: adapter().list()
end
