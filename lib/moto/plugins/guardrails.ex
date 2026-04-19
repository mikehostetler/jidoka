defmodule Moto.Plugins.Guardrails do
  @moduledoc false

  use Moto.Plugin,
    name: "moto_guardrails",
    state_key: :moto_guardrails,
    description: "Internal Moto tool guardrail interception",
    singleton: true,
    tools: [Moto.Actions.Guardrails.RejectToolCall],
    signal_patterns: ["ai.llm.response"]

  @impl Jido.Plugin
  def handle_signal(signal, context) do
    case Moto.Guardrails.tool_signal_override(signal, context.agent) do
      :continue ->
        {:ok, :continue}

      {:override, params} ->
        {:ok, {:override, {Moto.Actions.Guardrails.RejectToolCall, params}}}
    end
  end
end
