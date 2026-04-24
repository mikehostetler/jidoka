defmodule Jidoka.Examples.KitchenSink.Tools.ShowContext do
  use Jidoka.Tool,
    description: "Summarizes the public runtime context keys visible to tools.",
    schema: Zoi.object(%{})

  @impl true
  def run(_params, context) do
    public_context = Jidoka.Context.sanitize_for_subagent(context)

    {:ok,
     %{
       keys: public_context |> Map.keys() |> Enum.map(&to_string/1) |> Enum.sort(),
       tenant: Map.get(public_context, :tenant, Map.get(public_context, "tenant")),
       channel: Map.get(public_context, :channel, Map.get(public_context, "channel"))
     }}
  end
end
