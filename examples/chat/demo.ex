defmodule Bagu.Examples.Chat.Demo do
  @moduledoc false

  alias Bagu.Demo.{AgentSession, CLI, Debug, Inventory}

  @spec main([String.t()]) :: :ok
  def main(argv) do
    CLI.run_command(argv, "chat", fn -> :ok end, &run/2)
  end

  @spec usage() :: :ok
  def usage, do: CLI.usage("chat")

  defp run(options, log_level) do
    print_header(log_level)
    CLI.print_log_status(log_level)

    CLI.with_started_agent(
      options,
      log_level,
      fn -> agent_module().start_link(id: "script-chat-agent") end,
      fn pid, level -> AgentSession.interactive_loop(pid, level, session_opts()) end,
      fn pid, prompt, level -> AgentSession.one_shot(pid, prompt, level, session_opts()) end
    )
  end

  defp print_header(log_level) do
    Inventory.print_compiled("Bagu chat demo", agent_module(), log_level,
      try: [
        ~s(mix bagu chat -- "Add 8 and 13."),
        ~s(mix bagu chat -- "Remember that my favorite color is blue.")
      ]
    )
  end

  defp session_opts do
    [
      try: [
        "Add 8 and 13.",
        "Remember that my favorite color is blue."
      ],
      interrupts: :demo_interrupt,
      chat: fn pid, prompt, level, mode ->
        session = if mode == :interactive, do: "interactive", else: "cli"

        agent_module().chat(pid, prompt,
          context: %{notify_pid: self(), session: session},
          log_level: Debug.request_log_level(level)
        )
      end
    ]
  end

  defp agent_module do
    Module.concat([Bagu, Examples, Chat, Agents, ChatAgent])
  end
end
