defmodule Bagu.Agent.Verifiers.VerifyHooks do
  @moduledoc false

  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    dsl_state
    |> Spark.Dsl.Verifier.get_entities([:lifecycle])
    |> Enum.filter(&hook_entity?/1)
    |> Enum.reduce_while({:ok, default_seen()}, fn
      hook_ref, {:ok, seen} ->
        stage = stage_for(hook_ref)

        cond do
          duplicate_ref?(seen, stage, hook_ref.hook) ->
            {:halt, {:error, duplicate_hook_error(dsl_state, hook_ref, stage)}}

          true ->
            case Bagu.Hooks.validate_dsl_hook_ref(stage, hook_ref.hook) do
              :ok ->
                {:cont, {:ok, put_seen(seen, stage, hook_ref.hook)}}

              {:error, message} ->
                {:halt, {:error, hook_error(dsl_state, hook_ref, message)}}
            end
        end
    end)
    |> case do
      {:ok, _seen} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp stage_for(%Bagu.Agent.Dsl.BeforeTurnHook{}), do: :before_turn
  defp stage_for(%Bagu.Agent.Dsl.AfterTurnHook{}), do: :after_turn
  defp stage_for(%Bagu.Agent.Dsl.InterruptHook{}), do: :on_interrupt

  defp hook_entity?(%Bagu.Agent.Dsl.BeforeTurnHook{}), do: true
  defp hook_entity?(%Bagu.Agent.Dsl.AfterTurnHook{}), do: true
  defp hook_entity?(%Bagu.Agent.Dsl.InterruptHook{}), do: true
  defp hook_entity?(_other), do: false

  defp hook_error(dsl_state, hook_ref, message) do
    Spark.Error.DslError.exception(
      message: message,
      path: [:lifecycle, stage_for(hook_ref)],
      module: Spark.Dsl.Verifier.get_persisted(dsl_state, :module),
      location: Spark.Dsl.Entity.anno(hook_ref)
    )
  end

  defp duplicate_hook_error(dsl_state, hook_ref, stage) do
    Spark.Error.DslError.exception(
      message: "hook #{inspect(hook_ref.hook)} is defined more than once for #{stage}",
      path: [:lifecycle, stage],
      module: Spark.Dsl.Verifier.get_persisted(dsl_state, :module),
      location: Spark.Dsl.Entity.anno(hook_ref)
    )
  end

  defp default_seen, do: %{before_turn: MapSet.new(), after_turn: MapSet.new(), on_interrupt: MapSet.new()}
  defp duplicate_ref?(seen, stage, ref), do: MapSet.member?(Map.fetch!(seen, stage), ref)
  defp put_seen(seen, stage, ref), do: Map.update!(seen, stage, &MapSet.put(&1, ref))
end
