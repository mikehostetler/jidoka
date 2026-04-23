defmodule Bagu.Examples.Chat.Plugins.MathPlugin do
  use Bagu.Plugin,
    description: "Provides math tools for the demo agent.",
    tools: [Bagu.Examples.Chat.Tools.AddNumbers]
end
