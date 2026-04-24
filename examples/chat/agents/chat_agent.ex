defmodule Jidoka.Examples.Chat.Agents.ChatAgent do
  use Jidoka.Agent

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
    plugin Jidoka.Examples.Chat.Plugins.MathPlugin
  end

  lifecycle do
    memory do
      mode :conversation
      namespace {:context, :session}
      capture :conversation
      retrieve limit: 4
      inject :instructions
    end

    before_turn Jidoka.Examples.Chat.Hooks.ReplyWithFinalAnswer
    after_turn Jidoka.Examples.Chat.Hooks.TagAfterTurn
    after_turn Jidoka.Examples.Chat.Hooks.RequireApprovalForRefunds
    on_interrupt Jidoka.Examples.Chat.Hooks.NotifyInterrupt

    input_guardrail Jidoka.Examples.Chat.Guardrails.BlockSecretPrompt
    output_guardrail Jidoka.Examples.Chat.Guardrails.BlockUnsafeReply
    tool_guardrail Jidoka.Examples.Chat.Guardrails.ApproveLargeMathTool
  end
end
