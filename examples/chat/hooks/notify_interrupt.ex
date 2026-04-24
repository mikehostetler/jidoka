defmodule Jidoka.Examples.Chat.Hooks.NotifyInterrupt do
  use Jidoka.Hook, name: "notify_interrupt"

  @impl true
  def call(%Jidoka.Hooks.InterruptInput{interrupt: interrupt}) do
    if pid = get_in(interrupt.data, [:notify_pid]) do
      send(pid, {:demo_interrupt, interrupt})
    end

    :ok
  end
end
