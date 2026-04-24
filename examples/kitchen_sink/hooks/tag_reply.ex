defmodule Jidoka.Examples.KitchenSink.Hooks.TagReply do
  use Jidoka.Hook, name: "tag_reply"

  @impl true
  def call(%Jidoka.Hooks.AfterTurn{outcome: {:ok, result}} = input) when is_binary(result) do
    tenant = Map.get(input.context, :tenant, Map.get(input.context, "tenant", "unknown"))
    {:ok, {:ok, "#{result}\n\n[kitchen_sink tenant=#{tenant}]"}}
  end

  def call(%Jidoka.Hooks.AfterTurn{} = input), do: {:ok, input.outcome}
end
