defmodule Jidoka.AttemptSupervisor do
  @moduledoc """
  Supervisor for attempt-level runtime processes.
  """

  use DynamicSupervisor

  @impl true
  def start_link(_opts) do
    DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
