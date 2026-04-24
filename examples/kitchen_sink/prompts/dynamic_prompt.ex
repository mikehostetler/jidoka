defmodule Jidoka.Examples.KitchenSink.Prompts.DynamicPrompt do
  @behaviour Jidoka.Agent.SystemPrompt

  @impl true
  def resolve_system_prompt(%{context: context}) do
    tenant = Map.get(context, :tenant, Map.get(context, "tenant", "demo"))
    actor = Map.get(context, :actor, Map.get(context, "actor", "anonymous"))

    {:ok,
     """
     You are the Jidoka kitchen sink showcase agent.
     You are serving tenant #{tenant} for actor #{inspect(actor)}.
     Prefer tools and specialists when they apply.
     Keep final replies concise and explain only the user-visible result.
     Do not expose internal hook, guardrail, memory, or subagent metadata unless asked.
     """}
  end
end
