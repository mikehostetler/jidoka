defmodule Bagu.Examples.Chat.Hooks.TagAfterTurn do
  use Bagu.Hook, name: "tag_after_turn"

  @impl true
  def call(%Bagu.Hooks.AfterTurn{outcome: {:ok, result}} = input) when is_binary(result) do
    tenant = Map.get(input.context, :tenant, Map.get(input.context, "tenant", "unknown"))
    {:ok, {:ok, "[after_turn tenant=#{tenant}] #{result}"}}
  end

  def call(%Bagu.Hooks.AfterTurn{} = input) do
    {:ok, input.outcome}
  end
end
