defmodule Moto.Examples.Support.Tools.LoadOrder do
  use Moto.Tool,
    description: "Loads a deterministic order snapshot for a support request.",
    schema: Zoi.object(%{account_id: Zoi.string(), order_id: Zoi.string()})

  alias Moto.Examples.Support.SupportData

  @impl true
  def run(%{account_id: account_id, order_id: order_id}, _context) do
    {:ok, SupportData.order_snapshot(account_id, order_id)}
  end
end
