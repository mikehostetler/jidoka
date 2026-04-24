defmodule Jidoka.Examples.KitchenSink.Plugins.ShowcasePlugin do
  use Jidoka.Plugin,
    name: "showcase_plugin",
    description: "Contributes showcase utility tools.",
    tools: [Jidoka.Examples.KitchenSink.Tools.ShowContext]
end
