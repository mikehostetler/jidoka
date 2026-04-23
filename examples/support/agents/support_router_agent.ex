defmodule Bagu.Examples.Support.Agents.SupportRouterAgent do
  use Bagu.Agent

  @context_fields %{
    channel: Zoi.string() |> Zoi.default("support_chat"),
    session: Zoi.string() |> Zoi.optional(),
    account_id: Zoi.string() |> Zoi.optional(),
    order_id: Zoi.string() |> Zoi.optional()
  }

  agent do
    id :support_router_agent
    description "Front-door support agent that delegates to specialist teammates."
    schema Zoi.object(@context_fields)
  end

  defaults do
    model :fast

    instructions """
    You are the front-door support agent.
    You have three specialist tools. When a request matches a specialist, call that specialist tool before answering.
    Call billing_specialist for refunds, credits, invoice questions, and payment issues.
    Call operations_specialist for order status, delivery problems, access issues, and troubleshooting.
    Call writer_specialist when asked to draft or rewrite a customer-facing reply.
    Delegate to exactly one specialist when the fit is clear and then return the specialist's answer with minimal framing.
    If no specialist is needed, answer directly and keep the reply concise.
    """
  end

  capabilities do
    subagent Bagu.Examples.Support.Agents.BillingSpecialistAgent,
      timeout: 30_000,
      forward_context: {:only, [:channel, :session, :account_id, :order_id]},
      result: :structured

    subagent Bagu.Examples.Support.Agents.OperationsSpecialistAgent,
      timeout: 30_000,
      forward_context: {:only, [:channel, :session, :account_id, :order_id]},
      result: :structured

    subagent Bagu.Examples.Support.Agents.WriterSpecialistAgent,
      timeout: 30_000,
      forward_context: {:only, [:channel, :session, :account_id]},
      result: :text
  end

  lifecycle do
    input_guardrail Bagu.Examples.Support.Guardrails.SensitiveDataGuardrail
  end
end
