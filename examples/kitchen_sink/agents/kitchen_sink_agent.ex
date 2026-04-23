defmodule Bagu.Examples.KitchenSink.Agents.KitchenSinkAgent do
  use Bagu.Agent

  @context_fields %{
    tenant: Zoi.string() |> Zoi.default("demo"),
    channel: Zoi.string() |> Zoi.default("kitchen_sink"),
    session: Zoi.string() |> Zoi.optional(),
    actor: Zoi.any() |> Zoi.default(%{id: "demo-actor"}),
    notify_pid: Zoi.any() |> Zoi.optional()
  }

  agent do
    id :kitchen_sink_agent

    schema Zoi.object(@context_fields)
  end

  defaults do
    model :fast
    instructions Bagu.Examples.KitchenSink.Prompts.DynamicPrompt
  end

  capabilities do
    skill "kitchen-guidelines"
    load_path "../skills"
    tool Bagu.Examples.KitchenSink.Tools.AddNumbers
    ash_resource Bagu.Examples.KitchenSink.Ash.User
    mcp_tools endpoint: :local_fs, prefix: "fs_"
    plugin Bagu.Examples.KitchenSink.Plugins.ShowcasePlugin

    subagent Bagu.Examples.KitchenSink.Agents.ResearchAgent,
      as: "research_agent",
      description: "Ask the research specialist for concise factual notes",
      timeout: 30_000,
      forward_context: {:only, [:tenant, :channel, :session]},
      result: :structured

    subagent Bagu.Examples.KitchenSink.Subagents.ImportedEditorSpecialist,
      as: "editor_specialist",
      description: "Ask the imported editor specialist to polish text",
      timeout: 30_000,
      forward_context: {:except, [:notify_pid]},
      result: :text
  end

  lifecycle do
    memory do
      mode :conversation
      namespace {:context, :session}
      capture :conversation
      retrieve limit: 4
      inject :instructions
    end

    before_turn Bagu.Examples.KitchenSink.Hooks.ShapeTurn
    after_turn Bagu.Examples.KitchenSink.Hooks.TagReply
    on_interrupt Bagu.Examples.KitchenSink.Hooks.NotifyInterrupt

    input_guardrail Bagu.Examples.KitchenSink.Guardrails.BlockClassifiedPrompt
    output_guardrail Bagu.Examples.KitchenSink.Guardrails.BlockUnsafeReply
    tool_guardrail Bagu.Examples.KitchenSink.Guardrails.ApproveLargeMathTool
  end
end
