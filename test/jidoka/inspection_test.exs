defmodule JidokaTest.InspectionTest do
  use JidokaTest.Support.Case, async: false

  alias Jido.AI.Request
  alias JidokaTest.AddNumbers

  test "inspects a compiled Jidoka agent module" do
    assert {:ok, definition} = Jidoka.inspect_agent(JidokaTest.ToolAgent)

    assert definition.kind == :agent_definition
    assert definition.module == JidokaTest.ToolAgent
    assert definition.runtime_module == JidokaTest.ToolAgent.runtime_module()
    assert definition.name == "tool_agent"
    assert definition.tool_names == ["add_numbers"]
    assert definition.plugins == []
  end

  test "inspects an imported Jidoka agent definition" do
    assert {:ok, agent} =
             Jidoka.import_agent(
               %{
                 "agent" => %{"id" => "inspect_imported"},
                 "defaults" => %{
                   "model" => "fast",
                   "instructions" => "You are concise."
                 },
                 "capabilities" => %{"tools" => ["add_numbers"]}
               },
               available_tools: [AddNumbers]
             )

    assert {:ok, definition} = Jidoka.inspect_agent(agent)

    assert definition.kind == :imported_agent_definition
    assert definition.module == nil
    assert definition.id == "inspect_imported"
    assert definition.name == "inspect_imported"
    assert definition.tool_names == ["add_numbers"]
    assert definition.runtime_module == agent.runtime_module
  end

  test "inspects a running Jidoka agent and includes the latest request summary" do
    {:ok, pid} = JidokaTest.ToolAgent.start_link(id: "inspect-running-tool-agent")

    try do
      request_id = "req-inspect-running-1"

      :sys.replace_state(pid, fn state ->
        request =
          state.agent
          |> Request.start_request(request_id, "inspect this")
          |> Request.complete_request(
            request_id,
            "42",
            meta: %{
              jidoka_debug: %{
                system_prompt: "You can use math tools.",
                tool_names: ["add_numbers"],
                message_count: 1
              }
            }
          )

        %{state | agent: request}
      end)

      assert {:ok, inspection} = Jidoka.inspect_agent(pid)

      assert inspection.kind == :running_agent
      assert inspection.runtime_module == JidokaTest.ToolAgent.runtime_module()
      assert inspection.definition.name == "tool_agent"
      assert inspection.definition.tool_names == ["add_numbers"]
      assert inspection.last_request_id == request_id
      assert inspection.last_request.input_message == "inspect this"
    after
      :ok = Jidoka.stop_agent(pid)
    end
  end

  test "inspects a request summary directly" do
    agent = new_runtime_agent(JidokaTest.ToolAgent.runtime_module())
    request_id = "req-inspect-summary-1"

    agent =
      agent
      |> Request.start_request(request_id, "original prompt")
      |> Request.complete_request(
        request_id,
        "42",
        meta: %{
          usage: %{input: 10, output: 2},
          jidoka_debug: %{
            system_prompt: "You can use math tools.",
            tool_names: ["add_numbers"],
            message_count: 1
          }
        }
      )

    assert {:ok, summary} = Jidoka.inspect_request(agent, request_id)
    assert summary.request_id == request_id
    assert summary.system_prompt == "You can use math tools."
    assert summary.tool_names == ["add_numbers"]
    assert summary.usage == %{input: 10, output: 2, total: nil, cost: nil}
  end
end
