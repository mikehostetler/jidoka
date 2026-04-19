defmodule Moto do
  @moduledoc """
  Minimal runtime facade for starting and discovering Moto agents.
  """

  @doc """
  Starts an agent under the shared `Moto.Runtime` instance.
  """
  @spec start_agent(module() | struct(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_agent(agent, opts \\ []), do: Moto.Runtime.start_agent(agent, opts)

  @doc """
  Stops an agent by PID or registered ID.
  """
  @spec stop_agent(pid() | String.t(), keyword()) :: :ok | {:error, :not_found}
  def stop_agent(pid_or_id, opts \\ []), do: Moto.Runtime.stop_agent(pid_or_id, opts)

  @doc """
  Looks up a running agent by ID.
  """
  @spec whereis(String.t(), keyword()) :: pid() | nil
  def whereis(id, opts \\ []), do: Moto.Runtime.whereis(id, opts)

  @doc """
  Lists all running agents.
  """
  @spec list_agents(keyword()) :: [{String.t(), pid()}]
  def list_agents(opts \\ []), do: Moto.Runtime.list_agents(opts)
end
