defmodule Moto.Examples.KitchenSink.Agents.ResearchAgent do
  use Moto.Agent

  agent do
    id(:kitchen_research_agent)

    schema(
      Zoi.object(%{
        tenant: Zoi.string() |> Zoi.optional(),
        channel: Zoi.string() |> Zoi.default("kitchen_sink"),
        session: Zoi.string() |> Zoi.optional(),
        specialty: Zoi.string() |> Zoi.default("research")
      })
    )
  end

  defaults do
    model(:fast)

    instructions("""
    You are a research specialist used by the Moto kitchen sink showcase.
    Return concise factual notes.
    Do not mention orchestration internals.
    """)
  end
end
