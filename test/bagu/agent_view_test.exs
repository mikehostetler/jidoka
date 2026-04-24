defmodule BaguTest.AgentViewTest do
  use ExUnit.Case, async: true

  alias Jido.Thread

  test "projects LLM context separately from visible messages" do
    thread =
      Thread.new(id: "thread-support-1")
      |> Thread.append([
        ai_message(:user, "I need a refund.", request_id: "req-1"),
        ai_message(:assistant, "", request_id: "req-1", tool_calls: [%{id: "call-1", name: "review_refund"}]),
        ai_message(:tool, ~s({"decision":"approve"}),
          request_id: "req-1",
          tool_call_id: "call-1",
          name: "review_refund"
        ),
        ai_message(:assistant, "The refund is approved.", request_id: "req-1")
      ])

    projection = Bagu.Agent.View.project(thread)

    assert projection.thread_id == "thread-support-1"
    assert projection.entry_count == 4
    assert Enum.map(projection.llm_context, & &1.role) == [:user, :assistant, :tool, :assistant]
    assert Enum.map(projection.visible_messages, & &1.role) == [:user, :assistant]
    assert Enum.map(projection.visible_messages, & &1.content) == ["I need a refund.", "The refund is approved."]

    assert [
             %{kind: :tool_call, label: "tool call: review_refund"},
             %{kind: :tool_result, label: "tool result: review_refund"}
           ] = projection.events
  end

  test "filters projections by context ref" do
    thread =
      Thread.new()
      |> Thread.append([
        ai_message(:user, "Default context", context_ref: "default"),
        ai_message(:user, "Support context", context_ref: "support")
      ])

    assert %{visible_messages: [%{content: "Default context"}]} = Bagu.Agent.View.project(thread)

    assert %{visible_messages: [%{content: "Support context"}]} =
             Bagu.Agent.View.project(thread, context_ref: "support")
  end

  defp ai_message(role, content, attrs) do
    payload =
      attrs
      |> Map.new()
      |> Map.merge(%{role: role, content: content, context_ref: Keyword.get(attrs, :context_ref, "default")})

    %{
      kind: :ai_message,
      payload: payload,
      refs: %{request_id: Map.get(payload, :request_id)}
    }
  end
end
