defmodule Moto.Examples.Support.SupportFns do
  @moduledoc false

  @spec finalize_refund_decision(map(), map()) :: map()
  def finalize_refund_decision(%{account_id: account_id, order_id: order_id, policy: policy, reason: reason}, _context) do
    %{
      workflow: :refund_review,
      account_id: account_id,
      order_id: order_id,
      reason: reason,
      decision: policy.decision,
      refund_type: policy.refund_type,
      rationale: policy.rationale,
      next_action: policy.next_action
    }
  end

  @spec build_escalation_prompt(map(), map()) :: map()
  def build_escalation_prompt(
        %{account_id: account_id, classification: classification, issue: issue, channel: channel},
        _context
      ) do
    prompt = """
    Draft an internal support escalation note.
    Account: #{account_id}
    Channel: #{channel}
    Severity: #{classification.severity}
    Queue: #{classification.queue}
    Human review required: #{classification.requires_human}
    SLA minutes: #{classification.sla_minutes}
    Customer issue: #{issue}

    Return 3 short bullet points:
    1. what happened
    2. what support should do next
    3. what to tell the customer
    """

    %{
      prompt: String.trim(prompt),
      queue: classification.queue,
      severity: classification.severity
    }
  end

  @spec finalize_escalation_result(map(), map()) :: map()
  def finalize_escalation_result(%{classification: classification, draft: draft}, _context) do
    %{
      workflow: :escalation_draft,
      severity: classification.severity,
      queue: classification.queue,
      requires_human: classification.requires_human,
      sla_minutes: classification.sla_minutes,
      draft: draft
    }
  end
end
