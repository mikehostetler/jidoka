defmodule Moto.Examples.KitchenSink.Guardrails.BlockClassifiedPrompt do
  use Moto.Guardrail, name: "block_classified_prompt"

  @impl true
  def call(%Moto.Guardrails.Input{message: message}) do
    if message |> String.downcase() |> String.contains?("classified") do
      {:error, :classified_prompt_blocked}
    else
      :ok
    end
  end
end
