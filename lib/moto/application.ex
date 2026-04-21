defmodule Moto.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [Moto.Subagent.Metadata, Moto.Runtime]

    opts = [strategy: :one_for_one, name: Moto.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
