defmodule Moto.Examples.Support.Tools.EvaluateRefundPolicy do
  use Moto.Tool,
    description: "Applies a deterministic refund policy to a support case.",
    schema:
      Zoi.object(%{
        customer: Zoi.map(),
        order: Zoi.map(),
        reason: Zoi.string()
      })

  alias Moto.Examples.Support.SupportData

  @impl true
  def run(%{customer: customer, order: order, reason: reason}, _context) do
    {:ok, SupportData.refund_policy(customer, order, reason)}
  end
end
