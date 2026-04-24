defmodule Jidoka.Plugins.RuntimeCompat do
  @moduledoc false

  use Jidoka.Plugin,
    name: "jidoka_runtime_compat",
    state_key: :jidoka_runtime_compat,
    description: "Internal Jidoka compatibility routes for Jido.AI runtime signals.",
    singleton: true

  @impl Jido.Plugin
  def signal_routes(_config) do
    [
      {"ai.tool.started", Jido.Actions.Control.Noop}
    ]
  end
end
