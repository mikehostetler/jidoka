defmodule Bagu.Examples.Orchestrator.Demo do
  @moduledoc false

  alias Bagu.Demo.{AgentSession, CLI, Debug, Inventory}

  @spec main([String.t()]) :: :ok
  def main(argv) do
    CLI.run_command(argv, "orchestrator", fn -> :ok end, &run/2)
  end

  @spec usage() :: :ok
  def usage, do: CLI.usage("orchestrator")

  defp run(options, log_level) do
    print_header(log_level)
    CLI.print_log_status(log_level)

    CLI.with_started_agent(
      options,
      log_level,
      fn -> agent_module().start_link(id: "script-orchestrator-agent") end,
      fn pid, level -> AgentSession.interactive_loop(pid, level, session_opts()) end,
      fn pid, prompt, level -> AgentSession.one_shot(pid, prompt, level, session_opts()) end
    )
  end

  defp print_header(log_level) do
    Inventory.print_compiled("Bagu orchestrator demo", agent_module(), log_level,
      try: [
        ~s(mix bagu orchestrator -- "Use the research_agent specialist to explain vector databases."),
        ~s(mix bagu orchestrator -- "Use the writer_specialist specialist to rewrite this copy: our setup is easier now.")
      ]
    )
  end

  defp session_opts do
    [
      try: [
        "Use the research_agent specialist to explain vector databases.",
        "Use the writer_specialist specialist to rewrite this copy: our setup is easier now."
      ],
      subagents: [empty: :print, result_preview?: true],
      chat: fn pid, prompt, level, _mode ->
        agent_module().chat(pid, prompt,
          context: %{session: "orchestrator-cli"},
          log_level: Debug.request_log_level(level)
        )
      end
    ]
  end

  defp agent_module do
    Module.concat([Bagu, Examples, Orchestrator, Agents, ManagerAgent])
  end
end
