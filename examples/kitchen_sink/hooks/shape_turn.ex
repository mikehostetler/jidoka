defmodule Jidoka.Examples.KitchenSink.Hooks.ShapeTurn do
  use Jidoka.Hook, name: "shape_turn"

  @impl true
  def call(%Jidoka.Hooks.BeforeTurn{} = input) do
    tenant = Map.get(input.context, :tenant, Map.get(input.context, "tenant"))

    {:ok,
     %{
       message: "#{input.message}\n\nUse Jidoka capabilities when helpful.",
       metadata: %{tenant: tenant, showcase_hook: :before_turn}
     }}
  end
end
