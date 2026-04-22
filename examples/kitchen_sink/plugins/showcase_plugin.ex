defmodule Moto.Examples.KitchenSink.Plugins.ShowcasePlugin do
  use Moto.Plugin,
    name: "showcase_plugin",
    description: "Contributes showcase utility tools.",
    tools: [Moto.Examples.KitchenSink.Tools.ShowContext]
end
