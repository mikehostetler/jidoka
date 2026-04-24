defmodule Jidoka.Examples.Support.Workflows.EscalationDraft do
  @moduledoc false

  use Jidoka.Workflow

  alias Jidoka.Examples.Support.Agents.WriterSpecialistAgent
  alias Jidoka.Examples.Support.SupportFns
  alias Jidoka.Examples.Support.Tools.{ClassifyEscalation, LoadCustomerProfile}

  workflow do
    id :escalation_draft
    description "Deterministic escalation workflow with a bounded writer-agent step."

    input Zoi.object(%{
            account_id: Zoi.string(),
            issue: Zoi.string(),
            channel: Zoi.string() |> Zoi.default("support_portal")
          })
  end

  steps do
    tool :customer, LoadCustomerProfile, input: %{account_id: input(:account_id)}

    tool :classification, ClassifyEscalation,
      input: %{
        customer: from(:customer),
        issue: input(:issue)
      }

    function :prompt, {SupportFns, :build_escalation_prompt, 2},
      input: %{
        account_id: input(:account_id),
        classification: from(:classification),
        issue: input(:issue),
        channel: input(:channel)
      }

    agent :draft, WriterSpecialistAgent,
      prompt: from(:prompt, :prompt),
      context: %{
        account_id: input(:account_id),
        channel: input(:channel)
      }

    function :result, {SupportFns, :finalize_escalation_result, 2},
      input: %{
        classification: from(:classification),
        draft: from(:draft)
      }
  end

  output from(:result)
end
