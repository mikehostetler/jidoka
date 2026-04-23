defmodule Bagu.Examples.Chat.Guardrails.BlockSecretPrompt do
  use Bagu.Guardrail, name: "block_secret_prompt"

  @impl true
  def call(%Bagu.Guardrails.Input{message: message}) do
    if String.contains?(String.downcase(message), "secret") do
      {:error, :secret_prompt_blocked}
    else
      :ok
    end
  end
end
