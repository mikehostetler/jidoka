defmodule Jidoka.Examples.Support.Tools.EvaluateRefundPolicy do
  use Jidoka.Tool,
    description: "Applies a deterministic refund policy to a support case.",
    schema:
      Zoi.object(%{
        customer: Zoi.map(),
        order: Zoi.map(),
        reason: Zoi.string()
      })

  alias Jidoka.Examples.Support.SupportData

  @impl true
  def run(%{customer: customer, order: order, reason: reason}, _context) do
    {:ok, SupportData.refund_policy(customer, order, reason)}
  end
end
