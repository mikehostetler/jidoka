defmodule Jidoka.Bus do
  @moduledoc """
  Minimal in-memory event bus used to support snapshot restore and visibility.

  The bus stores a bounded list of signal events for the current process lifetime.
  """

  use GenServer

  @type signal :: map() | struct()
  @type log_entry :: %{
          path: String.t(),
          signal: signal(),
          recorded_at: DateTime.t()
        }

  defstruct [:entries]

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def record(signal, path) when is_binary(path) do
    GenServer.cast(__MODULE__, {:record, %{path: path, signal: signal}})
  end

  def get_log(opts \\ []) do
    pattern = Keyword.get(opts, :path)
    GenServer.call(__MODULE__, {:get_log, pattern})
  end

  def clear_log(opts \\ []) do
    pattern = Keyword.get(opts, :path)
    GenServer.call(__MODULE__, {:clear_log, pattern})
  end

  @impl true
  def init(:ok) do
    {:ok, %__MODULE__{entries: []}}
  end

  @impl true
  def handle_cast({:record, event}, state) do
    entry = %{
      path: event.path,
      signal: event.signal,
      recorded_at: DateTime.utc_now() |> DateTime.truncate(:microsecond)
    }

    {:noreply, %{state | entries: state.entries ++ [entry]}}
  end

  @impl true
  def handle_call({:get_log, nil}, _from, state), do: {:reply, {:ok, state.entries}, state}

  def handle_call({:get_log, pattern}, _from, state) when is_binary(pattern) do
    {:reply, {:ok, Enum.filter(state.entries, &path_match?(pattern, &1.path))}, state}
  end

  def handle_call({:clear_log, nil}, _from, state) do
    {:reply, :ok, %{state | entries: []}}
  end

  def handle_call({:clear_log, pattern}, _from, state) when is_binary(pattern) do
    remaining = Enum.reject(state.entries, &path_match?(pattern, &1.path))
    {:reply, :ok, %{state | entries: remaining}}
  end

  defp path_match?(pattern, value) when is_binary(pattern) and is_binary(value) do
    base =
      pattern
      |> String.trim_trailing("**")
      |> String.trim_trailing("/")

    String.starts_with?(value, base)
  end

  defp path_match?(_, _), do: false
end
