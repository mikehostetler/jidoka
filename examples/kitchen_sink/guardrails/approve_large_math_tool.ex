defmodule Bagu.Examples.KitchenSink.Guardrails.ApproveLargeMathTool do
  use Bagu.Guardrail, name: "approve_large_math_tool"

  @threshold 100

  @impl true
  def call(%Bagu.Guardrails.Tool{tool_name: "add_numbers", arguments: arguments, context: context}) do
    a = Map.get(arguments, :a, Map.get(arguments, "a", 0))
    b = Map.get(arguments, :b, Map.get(arguments, "b", 0))

    if a + b > @threshold do
      {:interrupt,
       %{
         kind: :approval,
         message: "Large math tool calls require approval in the kitchen sink demo.",
         data: %{
           notify_pid: Map.get(context, :notify_pid, Map.get(context, "notify_pid")),
           tenant: Map.get(context, :tenant, Map.get(context, "tenant")),
           reason: :large_math_tool_call
         }
       }}
    else
      :ok
    end
  end

  def call(%Bagu.Guardrails.Tool{}), do: :ok
end
