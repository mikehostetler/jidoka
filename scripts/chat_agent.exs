defmodule Moto.Scripts.ChatAgent do
  use Moto.Agent

  agent do
    name "script_chat_agent"
    system_prompt "You are a concise assistant. Keep answers short and direct."
  end
end

defmodule Moto.Scripts.ChatAgentCLI do
  alias Moto.Scripts.ChatAgent
  require Logger

  def main(argv) do
    argv = normalize_argv(argv)
    resolved_model = Jido.AI.resolve_model(:fast)
    anthropic_api_key = Application.get_env(:req_llm, :anthropic_api_key)

    Logger.configure(level: :error)

    IO.puts("Moto demo agent")
    IO.puts("Model alias: :fast")
    IO.puts("Resolved model: #{resolved_model}")
    IO.puts("")

    if is_nil(anthropic_api_key) or anthropic_api_key == "" do
      IO.puts("ANTHROPIC_API_KEY is not configured.")
      IO.puts("Add it to .env or export it in your shell.")
      System.halt(1)
    end

    {:ok, pid} = ChatAgent.start_link(id: "script-chat-agent")

    try do
      case argv do
        [] -> interactive_loop(pid)
        _ -> one_shot(pid, Enum.join(argv, " "))
      end
    after
      :ok = Moto.stop_agent(pid)
    end
  end

  defp normalize_argv(["--" | rest]), do: rest
  defp normalize_argv(argv), do: argv

  defp one_shot(pid, prompt) do
    case ChatAgent.chat(pid, prompt) do
      {:ok, reply} ->
        IO.puts(reply)

      {:error, reason} ->
        IO.puts("error: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp interactive_loop(pid) do
    IO.puts("Enter a prompt. Type `exit` or press Ctrl-D to quit.")
    IO.puts("")
    loop(pid)
  end

  defp loop(pid) do
    case IO.gets("you> ") do
      nil ->
        :ok

      input ->
        prompt = String.trim(input)

        cond do
          prompt == "" ->
            loop(pid)

          prompt in ["exit", "quit"] ->
            :ok

          true ->
            case ChatAgent.chat(pid, prompt) do
              {:ok, reply} ->
                IO.puts("")
                IO.puts("claude> #{reply}")
                IO.puts("")
                loop(pid)

              {:error, reason} ->
                IO.puts("")
                IO.puts("error> #{inspect(reason)}")
                IO.puts("")
                loop(pid)
            end
        end
    end
  end
end

Moto.Scripts.ChatAgentCLI.main(System.argv())
