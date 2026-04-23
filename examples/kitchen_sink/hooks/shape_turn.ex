defmodule Bagu.Examples.KitchenSink.Hooks.ShapeTurn do
  use Bagu.Hook, name: "shape_turn"

  @impl true
  def call(%Bagu.Hooks.BeforeTurn{} = input) do
    tenant = Map.get(input.context, :tenant, Map.get(input.context, "tenant"))

    {:ok,
     %{
       message: "#{input.message}\n\nUse Bagu capabilities when helpful.",
       metadata: %{tenant: tenant, showcase_hook: :before_turn}
     }}
  end
end
