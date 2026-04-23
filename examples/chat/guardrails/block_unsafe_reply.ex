defmodule Bagu.Examples.Chat.Guardrails.BlockUnsafeReply do
  use Bagu.Guardrail, name: "block_unsafe_reply"

  @impl true
  def call(%Bagu.Guardrails.Output{outcome: {:ok, result}}) when is_binary(result) do
    if String.contains?(String.downcase(result), "unsafe") do
      {:error, :unsafe_reply_blocked}
    else
      :ok
    end
  end

  def call(%Bagu.Guardrails.Output{}), do: :ok
end
