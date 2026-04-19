defmodule Moto.Actions.Guardrails.RejectToolCall do
  @moduledoc false

  use Jido.Action,
    name: "moto_reject_tool_call",
    schema:
      Zoi.object(%{
        request_id: Zoi.string(),
        guardrail_label: Zoi.string(),
        reason: Zoi.any(),
        message: Zoi.string(),
        interrupt: Zoi.any() |> Zoi.optional()
      })

  alias Jido.AI.Signal.RequestError
  alias Jido.Agent.Directive
  alias Jido.Agent.StateOp
  alias Moto.Interrupt

  @impl true
  def run(params, context) do
    request_id = params.request_id
    interrupt = normalize_interrupt(params[:interrupt])

    meta =
      if interrupt do
        %{interrupt: interrupt}
      else
        %{error: {:guardrail, :tool, params.guardrail_label, params.reason}}
      end

    if interrupt do
      agent = Map.get(context, :agent) || %{state: Map.get(context, :state, %{})}
      Moto.Hooks.notify_interrupt(agent, request_id, interrupt)
    end

    error_signal =
      RequestError.new!(%{
        request_id: request_id,
        reason: :guardrail_violation,
        message: params.message
      })

    {:ok, %{},
     [
       StateOp.set_state(%{
         requests: %{
           request_id => %{
             meta: %{
               moto_guardrails: meta
             }
           }
         }
       }),
       %Directive.Emit{signal: error_signal}
     ]}
  end

  defp normalize_interrupt(nil), do: nil
  defp normalize_interrupt(%Interrupt{} = interrupt), do: interrupt
  defp normalize_interrupt(interrupt), do: Interrupt.new(interrupt)
end
