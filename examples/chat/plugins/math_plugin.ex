defmodule Jidoka.Examples.Chat.Plugins.MathPlugin do
  use Jidoka.Plugin,
    description: "Provides math tools for the demo agent.",
    tools: [Jidoka.Examples.Chat.Tools.AddNumbers]
end
