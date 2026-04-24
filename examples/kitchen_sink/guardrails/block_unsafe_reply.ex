defmodule Jidoka.Examples.KitchenSink.Guardrails.BlockUnsafeReply do
  use Jidoka.Guardrail, name: "block_unsafe_reply"

  @impl true
  def call(%Jidoka.Guardrails.Output{outcome: {:ok, result}}) when is_binary(result) do
    if result |> String.downcase() |> String.contains?("unsafe") do
      {:error, :unsafe_reply_blocked}
    else
      :ok
    end
  end

  def call(%Jidoka.Guardrails.Output{}), do: :ok
end
