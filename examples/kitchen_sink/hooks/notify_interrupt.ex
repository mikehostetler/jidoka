defmodule Moto.Examples.KitchenSink.Hooks.NotifyInterrupt do
  use Moto.Hook, name: "notify_interrupt"

  @impl true
  def call(%Moto.Hooks.InterruptInput{interrupt: interrupt}) do
    notify_pid = get_in(interrupt.data, [:notify_pid])

    if is_pid(notify_pid) do
      send(notify_pid, {:kitchen_sink_interrupt, interrupt})
    end

    :ok
  end
end
