defmodule Moto.Agent.Verifiers.VerifyGuardrails do
  @moduledoc false

  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    dsl_state
    |> Spark.Dsl.Verifier.get_entities([:guardrails])
    |> Enum.reduce_while(:ok, fn guardrail_ref, :ok ->
      case Moto.Guardrails.validate_dsl_guardrail_ref(
             stage_for(guardrail_ref),
             guardrail_ref.guardrail
           ) do
        :ok ->
          {:cont, :ok}

        {:error, message} ->
          {:halt, {:error, guardrail_error(dsl_state, guardrail_ref, message)}}
      end
    end)
  end

  defp stage_for(%Moto.Agent.Dsl.InputGuardrail{}), do: :input
  defp stage_for(%Moto.Agent.Dsl.OutputGuardrail{}), do: :output
  defp stage_for(%Moto.Agent.Dsl.ToolGuardrail{}), do: :tool

  defp guardrail_error(dsl_state, guardrail_ref, message) do
    Spark.Error.DslError.exception(
      message: message,
      path: [:guardrails, stage_for(guardrail_ref)],
      module: Spark.Dsl.Verifier.get_persisted(dsl_state, :module),
      location: Spark.Dsl.Entity.anno(guardrail_ref)
    )
  end
end
