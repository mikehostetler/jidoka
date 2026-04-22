defmodule Moto.Examples.KitchenSink.Hooks.ShapeTurn do
  use Moto.Hook, name: "shape_turn"

  @impl true
  def call(%Moto.Hooks.BeforeTurn{} = input) do
    tenant = Map.get(input.context, :tenant, Map.get(input.context, "tenant"))

    {:ok,
     %{
       message: "#{input.message}\n\nUse Moto capabilities when helpful.",
       metadata: %{tenant: tenant, showcase_hook: :before_turn}
     }}
  end
end
