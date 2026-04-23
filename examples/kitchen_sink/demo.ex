defmodule Bagu.Examples.KitchenSink.Demo do
  @moduledoc false

  alias Bagu.Demo.{AgentSession, CLI, Debug, Inventory}

  @spec main([String.t()]) :: :ok
  def main(argv) do
    CLI.run_command(argv, "kitchen_sink", fn -> :ok end, &run/2)
  end

  @spec usage() :: :ok
  def usage, do: CLI.usage("kitchen_sink")

  defp run(options, log_level) do
    print_header(log_level)
    CLI.print_log_status(log_level)

    CLI.with_started_agent(
      options,
      log_level,
      fn ->
        prepare_mcp_sandbox!()
        agent_module().start_link(id: "script-kitchen-sink-agent")
      end,
      fn pid, level -> AgentSession.interactive_loop(pid, level, session_opts()) end,
      fn pid, prompt, level -> AgentSession.one_shot(pid, prompt, level, session_opts()) end
    )
  end

  defp print_header(log_level) do
    Inventory.print_compiled("Bagu kitchen sink demo", agent_module(), log_level,
      notice: "Showcase only: start with `mix bagu chat` for the simple path.",
      try: [
        ~s(mix bagu kitchen_sink -- "Add 17 and 25 with the tool."),
        ~s(mix bagu kitchen_sink -- "Show what runtime context is visible."),
        ~s(mix bagu kitchen_sink -- "Use the research_agent specialist to explain embeddings."),
        ~s(mix bagu kitchen_sink -- "Use the editor_specialist to polish: Bagu makes agents easier.")
      ]
    )
  end

  defp prepare_mcp_sandbox! do
    sandbox = Path.expand("../../tmp/mcp-sandbox", __DIR__)
    File.mkdir_p!(sandbox)
    File.write!(Path.join(sandbox, "kitchen-sink.txt"), "hello from the Bagu kitchen sink demo\n")
  end

  defp session_opts do
    [
      try: [
        "Add 17 and 25 with the tool.",
        "Show what runtime context is visible.",
        "Use the research_agent specialist to explain embeddings.",
        "Use the editor_specialist to polish: Bagu makes agents easier."
      ],
      interrupts: :kitchen_sink_interrupt,
      subagents: [empty: :silent],
      chat: fn pid, prompt, level, _mode ->
        agent_module().chat(pid, prompt,
          context: %{notify_pid: self(), session: "kitchen-sink-cli"},
          log_level: Debug.request_log_level(level)
        )
      end
    ]
  end

  defp agent_module do
    Module.concat([Bagu, Examples, KitchenSink, Agents, KitchenSinkAgent])
  end
end
