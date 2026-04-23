defmodule Moto.Examples.Chat.ImportedDemo do
  @moduledoc false

  alias Moto.Demo.{AgentSession, CLI, Debug, Inventory}

  alias Moto.Examples.Chat.Guardrails.{
    ApproveLargeMathTool,
    BlockSecretPrompt,
    BlockUnsafeReply
  }

  alias Moto.Examples.Chat.Hooks.ReplyWithFinalAnswer
  alias Moto.Examples.Chat.Tools.AddNumbers
  require Logger

  @spec main([String.t()]) :: :ok | no_return()
  def main(argv) do
    CLI.run_command(argv, "imported", fn -> :ok end, &run/2)
  end

  @spec usage() :: :ok
  def usage, do: CLI.usage("imported")

  defp run(options, log_level) do
    spec_path = sample_spec_path()
    available_tools = [AddNumbers]
    available_hooks = [ReplyWithFinalAnswer]
    available_guardrails = [BlockSecretPrompt, BlockUnsafeReply, ApproveLargeMathTool]
    available_skills = []
    {:ok, tool_registry} = Moto.Tool.normalize_available_tools(available_tools)
    {:ok, hook_registry} = Moto.Hook.normalize_available_hooks(available_hooks)

    {:ok, guardrail_registry} =
      Moto.Guardrail.normalize_available_guardrails(available_guardrails)

    Logger.configure(level: :error)

    agent =
      Moto.import_agent_file!(spec_path,
        available_tools: available_tools,
        available_skills: available_skills,
        available_hooks: available_hooks,
        available_guardrails: available_guardrails
      )

    Inventory.print_imported("Moto imported-agent demo", agent, log_level,
      source: spec_path,
      registries: %{
        tools: Map.keys(tool_registry),
        skills: [],
        hooks: Map.keys(hook_registry),
        guardrails: Map.keys(guardrail_registry)
      },
      try: [
        ~s(mix moto imported -- "Use the add_numbers tool to add 17 and 25. Reply with only the sum."),
        ~s(mix moto imported --log-level trace -- "Use the add_numbers tool to add 8 and 13.")
      ]
    )

    CLI.print_log_status(log_level)

    CLI.with_started_agent(
      options,
      log_level,
      fn -> Moto.start_agent(agent, id: "imported-script-chat-agent") end,
      fn pid, level -> AgentSession.interactive_loop(pid, level, session_opts()) end,
      fn pid, prompt, level -> AgentSession.one_shot(pid, prompt, level, session_opts()) end
    )
  end

  defp sample_spec_path do
    Path.expand("imported/sample_math_agent.json", __DIR__)
  end

  defp session_opts do
    [
      intro: "Enter a prompt. Type `exit` or press Ctrl-D to quit.",
      try: ["Add 8 and 13."],
      interactive_reply_label: "claude",
      interrupts: :demo_interrupt,
      chat: fn pid, prompt, level, mode ->
        session = if mode == :interactive, do: "imported-interactive", else: "imported-cli"

        Moto.chat(pid, prompt,
          context: %{"session" => session, "notify_pid" => self()},
          log_level: Debug.request_log_level(level)
        )
      end
    ]
  end
end
