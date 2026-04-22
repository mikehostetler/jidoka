defmodule Moto.Examples.KitchenSink.Tools.AddNumbers do
  use Moto.Tool,
    description: "Adds two integers together.",
    schema: Zoi.object(%{a: Zoi.integer(), b: Zoi.integer()})

  @impl true
  def run(%{a: a, b: b}, context) do
    tenant = Map.get(context, :tenant, Map.get(context, "tenant", "unknown"))
    sum = a + b

    IO.puts("[kitchen_sink:tool:add_numbers tenant=#{tenant}] #{a} + #{b} = #{sum}")
    {:ok, %{sum: sum}}
  end
end
