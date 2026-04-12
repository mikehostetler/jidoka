defmodule Jidoka.Bus do
  @moduledoc """
  Thin facade over `Jido.Signal.Bus`.
  """

  alias Jido.Signal
  alias Jido.Signal.Bus, as: SignalBus

  @bus_name __MODULE__

  @spec bus_name() :: module()
  def bus_name, do: @bus_name

  @spec publish(Signal.t() | [Signal.t()]) :: {:ok, term()} | {:error, term()}
  def publish(%Signal{} = signal), do: SignalBus.publish(@bus_name, [signal])
  def publish(signals) when is_list(signals), do: SignalBus.publish(@bus_name, signals)

  @spec subscribe(String.t(), keyword()) :: {:ok, term()} | {:error, term()}
  def subscribe(path, opts \\ []) do
    SignalBus.subscribe(@bus_name, path, Keyword.put_new(opts, :dispatch, {:pid, target: self()}))
  end

  @spec unsubscribe(term(), keyword()) :: :ok | {:error, term()}
  def unsubscribe(subscription_id, opts \\ []) do
    SignalBus.unsubscribe(@bus_name, subscription_id, opts)
  end

  @spec get_log(keyword()) :: {:ok, term()} | {:error, term()}
  def get_log(opts \\ []) do
    path = Keyword.get(opts, :path, "*")
    start_timestamp = Keyword.get(opts, :start_timestamp, 0)
    replay_opts = Keyword.drop(opts, [:path, :start_timestamp])

    SignalBus.replay(@bus_name, path, start_timestamp, replay_opts)
  end
end
