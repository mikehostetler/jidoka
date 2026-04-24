defmodule Jidoka.Examples.Support.Agents.SupportRouterAgent do
  use Jidoka.Agent

  alias Jidoka.Examples.Support.Workflows.RefundReview

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
    You have specialist teammates and deterministic support workflows.
    If a refund request includes account id, order id, and a reason, call review_refund before answering.
    Call billing_specialist for ambiguous refund questions, credits, invoice questions, and payment issues.
    Call transfer_billing_ownership only when the user asks for ongoing billing follow-up or the next turn should belong to billing.
    Call operations_specialist for order status, delivery problems, access issues, and troubleshooting.
    Call writer_specialist when asked to draft or rewrite a customer-facing reply.
    Delegate to exactly one specialist or workflow when the fit is clear and then return the result with minimal framing.
    If no specialist is needed, answer directly and keep the reply concise.
    """
  end

  capabilities do
    workflow(RefundReview,
      as: :review_refund,
      description: "Review refund eligibility for a known account, order, and reason.",
      forward_context: {:only, [:channel, :session]},
      result: :structured
    )

    subagent Jidoka.Examples.Support.Agents.BillingSpecialistAgent,
      timeout: 30_000,
      forward_context: {:only, [:channel, :session, :account_id, :order_id]},
      result: :structured

    handoff Jidoka.Examples.Support.Agents.BillingSpecialistAgent,
      as: :transfer_billing_ownership,
      description: "Transfer ongoing billing conversation ownership to the billing specialist.",
      forward_context: {:only, [:channel, :session, :account_id, :order_id]}

    subagent Jidoka.Examples.Support.Agents.OperationsSpecialistAgent,
      timeout: 30_000,
      forward_context: {:only, [:channel, :session, :account_id, :order_id]},
      result: :structured

    subagent Jidoka.Examples.Support.Agents.WriterSpecialistAgent,
      timeout: 30_000,
      forward_context: {:only, [:channel, :session, :account_id]},
      result: :text
  end

  lifecycle do
    input_guardrail Jidoka.Examples.Support.Guardrails.SensitiveDataGuardrail
  end
end
