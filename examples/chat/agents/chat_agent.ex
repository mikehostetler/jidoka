defmodule Bagu.Examples.Chat.Agents.ChatAgent do
  use Bagu.Agent

  @context_fields %{
    tenant: Zoi.string() |> Zoi.default("demo"),
    channel: Zoi.string() |> Zoi.default("cli"),
    session: Zoi.string() |> Zoi.optional(),
    notify_pid: Zoi.any() |> Zoi.optional()
  }

  agent do
    id :script_chat_agent

    schema Zoi.object(@context_fields)
  end

  defaults do
    model :fast

    instructions """
    You are a concise assistant.
    Keep answers short and direct.
    """
  end

  capabilities do
    skill "math-discipline"
    load_path "../skills"
    plugin Bagu.Examples.Chat.Plugins.MathPlugin
  end

  lifecycle do
    memory do
      mode :conversation
      namespace {:context, :session}
      capture :conversation
      retrieve limit: 4
      inject :instructions
    end

    before_turn Bagu.Examples.Chat.Hooks.ReplyWithFinalAnswer
    after_turn Bagu.Examples.Chat.Hooks.TagAfterTurn
    after_turn Bagu.Examples.Chat.Hooks.RequireApprovalForRefunds
    on_interrupt Bagu.Examples.Chat.Hooks.NotifyInterrupt

    input_guardrail Bagu.Examples.Chat.Guardrails.BlockSecretPrompt
    output_guardrail Bagu.Examples.Chat.Guardrails.BlockUnsafeReply
    tool_guardrail Bagu.Examples.Chat.Guardrails.ApproveLargeMathTool
  end
end
