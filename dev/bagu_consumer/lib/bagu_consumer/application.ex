defmodule BaguConsumer.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Phoenix.PubSub, name: BaguConsumer.PubSub},
      BaguConsumerWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: BaguConsumer.Supervisor)
  end
end
