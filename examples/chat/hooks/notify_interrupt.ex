defmodule Bagu.Examples.Chat.Hooks.NotifyInterrupt do
  use Bagu.Hook, name: "notify_interrupt"

  @impl true
  def call(%Bagu.Hooks.InterruptInput{interrupt: interrupt}) do
    if pid = get_in(interrupt.data, [:notify_pid]) do
      send(pid, {:demo_interrupt, interrupt})
    end

    :ok
  end
end
