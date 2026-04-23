defmodule Bagu.Agent.Verifiers.VerifyMemory do
  @moduledoc false

  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    dsl_state
    |> Spark.Dsl.Verifier.get_entities([:lifecycle, :memory])
    |> Enum.reduce_while(:ok, fn entry, :ok ->
      case Bagu.Memory.validate_dsl_entry(entry) do
        :ok ->
          {:cont, :ok}

        {:error, message} ->
          {:halt,
           {:error,
            Spark.Error.DslError.exception(
              message: message,
              path: [:lifecycle, :memory, entry_name(entry)],
              module: Spark.Dsl.Verifier.get_persisted(dsl_state, :module),
              location: Spark.Dsl.Entity.anno(entry)
            )}}
      end
    end)
  end

  defp entry_name(%Bagu.Agent.Dsl.MemoryMode{}), do: :mode
  defp entry_name(%Bagu.Agent.Dsl.MemoryNamespace{}), do: :namespace
  defp entry_name(%Bagu.Agent.Dsl.MemorySharedNamespace{}), do: :shared_namespace
  defp entry_name(%Bagu.Agent.Dsl.MemoryCapture{}), do: :capture
  defp entry_name(%Bagu.Agent.Dsl.MemoryInject{}), do: :inject
  defp entry_name(%Bagu.Agent.Dsl.MemoryRetrieve{}), do: :retrieve
end
