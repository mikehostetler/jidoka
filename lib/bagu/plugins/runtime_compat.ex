defmodule Bagu.Plugins.RuntimeCompat do
  @moduledoc false

  use Bagu.Plugin,
    name: "bagu_runtime_compat",
    state_key: :bagu_runtime_compat,
    description: "Internal Bagu compatibility routes for Jido.AI runtime signals.",
    singleton: true

  @impl Jido.Plugin
  def signal_routes(_config) do
    [
      {"ai.tool.started", Jido.Actions.Control.Noop}
    ]
  end
end
