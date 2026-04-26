defmodule JidokaTest.KinoTest do
  use JidokaTest.Support.Case, async: false

  require Logger

  test "trace returns the wrapped result without Kino loaded" do
    result =
      Jidoka.Kino.trace("smoke", fn ->
        Logger.notice("Executing Jido.Actions.Control.Noop with params: %{query: \"hello\"}")
        :ok
      end)

    assert result == :ok
  end

  test "load_provider_env mirrors Livebook secret names" do
    previous_anthropic = System.get_env("ANTHROPIC_API_KEY")
    previous_livebook = System.get_env("LB_ANTHROPIC_API_KEY")

    System.delete_env("ANTHROPIC_API_KEY")
    System.put_env("LB_ANTHROPIC_API_KEY", "livebook-secret")

    try do
      assert Jidoka.Kino.load_provider_env() == {:ok, "LB_ANTHROPIC_API_KEY"}
      assert System.get_env("ANTHROPIC_API_KEY") == "livebook-secret"
    after
      restore_env("ANTHROPIC_API_KEY", previous_anthropic)
      restore_env("LB_ANTHROPIC_API_KEY", previous_livebook)
    end
  end

  test "chat returns a missing provider error before calling the provider" do
    previous_anthropic = System.get_env("ANTHROPIC_API_KEY")
    previous_livebook = System.get_env("LB_ANTHROPIC_API_KEY")

    System.delete_env("ANTHROPIC_API_KEY")
    System.delete_env("LB_ANTHROPIC_API_KEY")

    try do
      result =
        Jidoka.Kino.chat("missing provider", fn ->
          flunk("chat function should not run without provider configuration")
        end)

      assert {:error, message} = result
      assert message =~ "ANTHROPIC_API_KEY"
    after
      restore_env("ANTHROPIC_API_KEY", previous_anthropic)
      restore_env("LB_ANTHROPIC_API_KEY", previous_livebook)
    end
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)
end
