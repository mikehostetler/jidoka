defmodule Bagu.Examples.Support.Tools.ClassifyEscalation do
  use Bagu.Tool,
    description: "Classifies a support issue into a deterministic escalation queue.",
    schema:
      Zoi.object(%{
        customer: Zoi.map(),
        issue: Zoi.string()
      })

  alias Bagu.Examples.Support.SupportData

  @impl true
  def run(%{customer: customer, issue: issue}, _context) do
    {:ok, SupportData.escalation_classification(customer, issue)}
  end
end
