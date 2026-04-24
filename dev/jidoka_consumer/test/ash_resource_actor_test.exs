defmodule JidokaConsumer.AshResourceActorTest do
  use ExUnit.Case, async: false

  alias JidokaConsumer.Accounts
  alias JidokaConsumer.Accounts.SecureNote
  alias JidokaConsumer.SupportNoteAgent

  test "AshJido create succeeds when actor comes from scope" do
    actor = %{id: "scope_actor", name: "Scope User"}

    assert {:ok, note} =
             SecureNote.Jido.Create.run(
               %{title: "Scoped Secret", owner_id: actor.id},
               %{domain: Accounts, scope: %{actor: actor}}
             )

    assert note.title == "Scoped Secret"
    assert note.owner_id == "scope_actor"
  end

  test "AshJido create fails without actor or scope" do
    assert {:error, error} =
             SecureNote.Jido.Create.run(
               %{title: "Denied"},
               %{domain: Accounts, actor: nil}
             )

    assert error.details.reason == :forbidden
  end

  test "Jidoka ash_resource agents do not supply a default actor" do
    assert SupportNoteAgent.requires_actor?()

    assert {:ok, pid} = SupportNoteAgent.start_link(id: "support-note-agent")

    try do
      assert_missing_actor(fn ->
        SupportNoteAgent.chat(pid, "List secure notes.")
      end)

      assert_missing_actor(fn ->
        SupportNoteAgent.chat(
          pid,
          "List secure notes.",
          context: %{scope: %{actor: %{id: "scope_only"}}}
        )
      end)
    after
      :ok = Jidoka.stop_agent(pid)
    end
  end

  defp assert_missing_actor(fun) do
    assert {:error, %Jidoka.Error.ValidationError{} = error} = fun.()
    assert error.field == :actor
    assert error.details.reason == :missing_context
    assert error.details.key == :actor
  end
end
