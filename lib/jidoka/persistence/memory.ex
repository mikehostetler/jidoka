defmodule Jidoka.Persistence.Memory do
  @moduledoc false

  use GenServer

  @behaviour Jidoka.Persistence

  @table __MODULE__.Table

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    table =
      :ets.new(@table, [
        :named_table,
        :public,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

    {:ok, %{table: table}}
  end

  @impl true
  def load(session_ref) do
    case :ets.lookup(@table, session_ref) do
      [{^session_ref, state}] -> {:ok, state}
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def save(session_ref, state) do
    true = :ets.insert(@table, {session_ref, state})
    :ok
  end

  @impl true
  def delete(session_ref) do
    true = :ets.delete(@table, session_ref)
    :ok
  end

  @impl true
  def list do
    {:ok, :ets.tab2list(@table) |> Enum.map(&elem(&1, 0))}
  end
end
