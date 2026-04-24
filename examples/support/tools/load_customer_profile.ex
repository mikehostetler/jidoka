defmodule Jidoka.Examples.Support.Tools.LoadCustomerProfile do
  use Jidoka.Tool,
    description: "Loads a deterministic support customer profile.",
    schema: Zoi.object(%{account_id: Zoi.string()})

  alias Jidoka.Examples.Support.SupportData

  @impl true
  def run(%{account_id: account_id}, _context) do
    {:ok, SupportData.customer_profile(account_id)}
  end
end
