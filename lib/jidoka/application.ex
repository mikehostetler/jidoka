defmodule Jidoka.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Jidoka.RuntimeRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Jidoka.RuntimeSupervisor},
      Jidoka.Persistence.Memory,
      {Jido.Signal.Bus, name: Jidoka.Bus.bus_name()}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Jidoka.Supervisor)
  end
end
