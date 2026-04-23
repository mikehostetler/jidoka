defmodule Bagu.Examples.KitchenSink.Plugins.ShowcasePlugin do
  use Bagu.Plugin,
    name: "showcase_plugin",
    description: "Contributes showcase utility tools.",
    tools: [Bagu.Examples.KitchenSink.Tools.ShowContext]
end
