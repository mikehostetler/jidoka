defmodule Jidoka.AgentState do
  @moduledoc false

  @table __MODULE__

  @spec ensure(String.t(), keyword()) :: map()
  def ensure(session_ref, opts \\ []) when is_binary(session_ref) do
    ensure_table()

    case :ets.lookup(@table, session_ref) do
      [{^session_ref, state}] ->
        state

      [] ->
        state = new_state(session_ref, opts)
        true = :ets.insert(@table, {session_ref, state})
        state
    end
  end

  @spec get(String.t()) :: {:ok, map()} | :error
  def get(session_ref) when is_binary(session_ref) do
    ensure_table()

    case :ets.lookup(@table, session_ref) do
      [{^session_ref, state}] -> {:ok, state}
      [] -> :error
    end
  end

  @spec put(String.t(), map()) :: map()
  def put(session_ref, state) when is_binary(session_ref) and is_map(state) do
    ensure_table()
    true = :ets.insert(@table, {session_ref, state})
    state
  end

  @spec update(String.t(), (map() -> map())) :: map()
  def update(session_ref, fun) when is_binary(session_ref) and is_function(fun, 1) do
    state = ensure(session_ref)
    put(session_ref, fun.(state))
  end

  @spec delete(String.t()) :: :ok
  def delete(session_ref) when is_binary(session_ref) do
    ensure_table()
    true = :ets.delete(@table, session_ref)
    :ok
  end

  @spec refresh_resources(String.t()) :: {:ok, map()} | :error
  def refresh_resources(session_ref) when is_binary(session_ref) do
    case get(session_ref) do
      {:ok, state} ->
        resources = build_resources(state, state.resources.epoch + 1)
        put(session_ref, Map.put(state, :resources, resources))
        {:ok, resources}

      :error ->
        :error
    end
  end

  defp ensure_table do
    case :ets.info(@table) do
      :undefined ->
        :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])

      _ ->
        @table
    end
  end

  defp new_state(session_ref, opts) do
    resources = build_resources(opts, 1)

    %{
      session_ref: session_ref,
      cwd: Keyword.get(opts, :cwd, Keyword.get(opts, :workspace_path)),
      home: Keyword.get(opts, :home),
      transcript: [],
      requests: %{},
      branches: %{},
      branch_order: [],
      current_branch: nil,
      current_leaf: nil,
      resources: resources,
      metadata: %{thread_length: 0}
    }
  end

  defp build_resources(opts, epoch) when is_list(opts) do
    cwd = Keyword.get(opts, :cwd, Keyword.get(opts, :workspace_path))
    home = Keyword.get(opts, :home)

    build_resources(cwd, home, epoch)
  end

  defp build_resources(state, epoch) when is_map(state) do
    build_resources(state[:cwd], state[:home], epoch)
  end

  defp build_resources(cwd, home, epoch) do
    %{
      epoch: epoch,
      version: resource_version(cwd, home),
      cwd: cwd,
      home: home
    }
  end

  defp resource_version(cwd, home) do
    [
      read_optional(Path.join(cwd || "", "AGENTS.md")),
      read_optional(Path.join(home || "", "config.toml"))
    ]
    |> Enum.join("::")
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp read_optional(path) when is_binary(path) do
    case File.read(path) do
      {:ok, contents} -> contents
      {:error, _} -> ""
    end
  end
end
