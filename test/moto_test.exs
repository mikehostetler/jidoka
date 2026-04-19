defmodule MotoTest do
  use ExUnit.Case, async: false

  defmodule ChatAgent do
    use Moto.Agent

    agent do
      system_prompt("You are a concise assistant.")
    end
  end

  test "starts a moto agent under the shared runtime" do
    assert {:ok, pid} = ChatAgent.start_link(id: "chat-agent-test")
    assert is_pid(pid)
    assert Moto.whereis("chat-agent-test") == pid
    assert [{id, ^pid}] = Moto.list_agents()
    assert id == "chat-agent-test"
    assert :ok = Moto.stop_agent(pid)
  end

  test "defaults the agent name from the module" do
    assert ChatAgent.name() == "chat_agent"
    assert ChatAgent.runtime_module() == MotoTest.ChatAgent.Runtime
  end

  test "exposes the configured system prompt" do
    assert ChatAgent.system_prompt() == "You are a concise assistant."
  end

  test "rejects old keyword opts in favor of the DSL" do
    assert_raise CompileError, ~r/Moto.Agent now uses a Spark DSL/, fn ->
      Code.compile_string("""
      defmodule MotoTest.InvalidKeywordAgent do
        use Moto.Agent,
          system_prompt: "This should fail."
      end
      """)
    end
  end
end
