defmodule Bagu.Examples.KitchenSink.Guardrails.BlockClassifiedPrompt do
  use Bagu.Guardrail, name: "block_classified_prompt"

  @impl true
  def call(%Bagu.Guardrails.Input{message: message}) do
    if message |> String.downcase() |> String.contains?("classified") do
      {:error, :classified_prompt_blocked}
    else
      :ok
    end
  end
end
