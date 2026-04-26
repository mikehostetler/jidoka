defmodule Jidoka.Kino.LoggerHandler do
  @moduledoc false

  def adding_handler(config), do: {:ok, config}
  def removing_handler(_config), do: :ok
  def changing_config(_set_or_update, _old_config, new_config), do: {:ok, new_config}
  def filter_config(config), do: config

  def log(%{level: level, msg: message, meta: metadata}, %{config: %{collector: collector}}) do
    send(collector, {:jidoka_kino_log, %{level: level, message: format_message(message), metadata: metadata}})
  end

  defp format_message({:string, message}), do: to_string(message)
  defp format_message({:report, report}), do: inspect(report, pretty: true, limit: 50)

  defp format_message({:format, format, args}) do
    format
    |> :io_lib.format(args)
    |> IO.iodata_to_binary()
  rescue
    _error -> inspect({format, args}, limit: 50)
  end

  defp format_message(message), do: inspect(message, limit: 50)
end

defmodule Jidoka.Kino do
  @moduledoc """
  Small Livebook helpers for Jidoka examples.

  `Jidoka.Kino` keeps notebook cells focused on the agent code. It configures
  quiet runtime logs, mirrors Livebook secrets into the provider environment,
  captures useful Jido/Jidoka log events, and renders those events with Kino
  when Kino is available.

  Kino is intentionally optional. This module compiles and runs without Kino;
  rendering becomes a no-op outside Livebook.
  """

  require Logger

  @provider_env_names ["ANTHROPIC_API_KEY", "LB_ANTHROPIC_API_KEY"]

  @doc """
  Configures the notebook runtime for concise Jidoka output.

  By default, raw runtime logs are quiet and provider-backed examples can rely
  on a Livebook secret named `ANTHROPIC_API_KEY`.
  """
  @spec setup(keyword()) :: :ok
  def setup(opts \\ []) do
    show_raw_logs? = Keyword.get(opts, :show_raw_logs, false)
    log_level = if(show_raw_logs?, do: :notice, else: :warning)

    Logger.configure(level: log_level)
    Jidoka.Runtime.debug(if(show_raw_logs?, do: :on, else: :off))
    _ = load_provider_env(Keyword.get(opts, :provider_env, @provider_env_names))

    :ok
  end

  @doc """
  Copies a Livebook provider secret into the environment name expected by ReqLLM.

  The default lookup accepts either `ANTHROPIC_API_KEY` or Livebook's
  `LB_ANTHROPIC_API_KEY`.
  """
  @spec load_provider_env([String.t()]) :: {:ok, String.t()} | {:error, String.t()}
  def load_provider_env(names \\ @provider_env_names) when is_list(names) do
    case find_env(names) do
      nil ->
        clear_empty_env("ANTHROPIC_API_KEY")
        {:error, "Set ANTHROPIC_API_KEY, or a Livebook secret named ANTHROPIC_API_KEY"}

      {"ANTHROPIC_API_KEY", _key} ->
        {:ok, "ANTHROPIC_API_KEY"}

      {name, key} ->
        System.put_env("ANTHROPIC_API_KEY", key)
        {:ok, name}
    end
  end

  @doc """
  Captures runtime log events around `fun` and renders a compact trace table.
  """
  @spec trace(String.t(), (-> result), keyword()) :: result when result: term()
  def trace(label, fun, opts \\ []) when is_binary(label) and is_function(fun, 0) do
    handler_id = :"jidoka_kino_trace_#{System.unique_integer([:positive])}"
    previous_logger_level = Logger.level()
    previous_handler_levels = handler_levels()

    :ok =
      :logger.add_handler(handler_id, Jidoka.Kino.LoggerHandler, %{
        level: Keyword.get(opts, :level, :debug),
        config: %{collector: self()}
      })

    Logger.configure(level: Keyword.get(opts, :level, :debug))

    unless Keyword.get(opts, :show_raw_logs, false) do
      set_handler_levels(previous_handler_levels, :warning)
    end

    try do
      result = fun.()
      flush_logs(Keyword.get(opts, :flush_ms, 100))
      events = drain_logs(Keyword.get(opts, :max_events, 200))
      render(label, events, opts)
      result
    after
      _ = :logger.remove_handler(handler_id)
      Logger.configure(level: previous_logger_level)
      restore_handler_levels(previous_handler_levels)
    end
  end

  @doc """
  Captures a provider-backed chat call and returns plain extracted text.
  """
  @spec chat(String.t(), (-> term()), keyword()) :: term()
  def chat(label, fun, opts \\ []) when is_binary(label) and is_function(fun, 0) do
    with {:ok, _source} <- load_provider_env(Keyword.get(opts, :provider_env, @provider_env_names)) do
      label
      |> trace(fun, opts)
      |> format_chat_result()
    end
  end

  @doc """
  Formats common Jidoka chat results for notebook output.
  """
  @spec format_chat_result(term()) :: term()
  def format_chat_result({:ok, turn}), do: {:ok, Jido.AI.Turn.extract_text(turn)}
  def format_chat_result({:error, reason}), do: {:error, Jidoka.format_error(reason)}
  def format_chat_result(other), do: other

  @doc """
  Renders a small Markdown table in Livebook.

  This avoids custom widget JavaScript, so it remains stable across Livebook and
  Kino versions.
  """
  @spec table(String.t(), [map()], keyword()) :: :ok
  def table(label, rows, opts \\ []) when is_binary(label) and is_list(rows) do
    keys = Keyword.get(opts, :keys, infer_keys(rows))

    rows
    |> markdown_table(label, keys)
    |> render_markdown()
  end

  defp find_env(names) do
    Enum.find_value(names, fn name ->
      case System.get_env(name) do
        nil -> nil
        "" -> nil
        key -> {name, key}
      end
    end)
  end

  defp clear_empty_env(name) do
    if System.get_env(name) == "" do
      System.delete_env(name)
    end
  end

  defp handler_levels do
    :logger.get_handler_ids()
    |> Enum.map(fn handler_id ->
      {handler_id, handler_level(handler_id)}
    end)
  end

  defp handler_level(handler_id) do
    case :logger.get_handler_config(handler_id) do
      {:ok, %{level: level}} -> level
      _other -> nil
    end
  end

  defp set_handler_levels(handler_levels, level) do
    Enum.each(handler_levels, fn {handler_id, _previous_level} ->
      set_handler_level(handler_id, level)
    end)
  end

  defp restore_handler_levels(handler_levels) do
    Enum.each(handler_levels, fn
      {_handler_id, nil} -> :ok
      {handler_id, level} -> set_handler_level(handler_id, level)
    end)
  end

  defp set_handler_level(handler_id, level) do
    _ = :logger.set_handler_config(handler_id, :level, level)
    :ok
  end

  defp flush_logs(ms) do
    receive do
    after
      ms -> :ok
    end
  end

  defp drain_logs(max_events), do: drain_logs(max_events, [], 0)

  defp drain_logs(max_events, events, count) do
    receive do
      {:jidoka_kino_log, event} ->
        events = if count < max_events, do: [event | events], else: events
        drain_logs(max_events, events, count + 1)
    after
      25 -> Enum.reverse(events)
    end
  end

  defp render(label, events, opts) do
    rows = Enum.map(events, &event_row/1)

    render_value("Runtime trace: #{label} (#{length(rows)} events)")

    if rows == [] do
      render_value("No runtime events were captured for this call.")
    else
      render_table(label, rows, opts)
    end

    :ok
  end

  defp render_table(label, rows, opts) do
    rows =
      case Keyword.fetch(opts, :num_rows) do
        {:ok, num_rows} -> Enum.take(rows, num_rows)
        :error -> rows
      end

    table(label, rows, keys: [:time, :level, :event, :source, :summary])
  end

  defp render_value(value) do
    if Code.ensure_loaded?(Kino) and function_exported?(Kino, :render, 1) do
      apply(Kino, :render, [value])
    else
      :ok
    end
  end

  defp render_markdown(markdown) do
    value =
      if Code.ensure_loaded?(Kino.Markdown) and function_exported?(Kino.Markdown, :new, 1) do
        apply(Kino.Markdown, :new, [markdown])
      else
        markdown
      end

    render_value(value)
  end

  defp event_row(%{level: level, message: message, metadata: metadata}) do
    %{
      time: format_time(Map.get(metadata, :time)),
      level: level |> to_string() |> String.upcase(),
      event: event_name(message),
      source: event_source(message, metadata),
      summary: summarize(message)
    }
  end

  defp format_time(nil), do: ""

  defp format_time(time) when is_integer(time) do
    time
    |> DateTime.from_unix!(:microsecond)
    |> DateTime.to_time()
    |> Time.to_iso8601()
    |> String.slice(0, 12)
  rescue
    _error -> ""
  end

  defp event_name(message) do
    cond do
      String.contains?(message, "spawned child") -> "spawn child"
      String.starts_with?(message, "Executing ") -> "action"
      String.contains?(message, "Reasoning") -> "reasoning"
      true -> "log"
    end
  end

  defp event_source(message, metadata) do
    cond do
      match = Regex.run(~r/AgentServer ([^\s]+)/, message) ->
        Enum.at(match, 1)

      match = Regex.run(~r/Executing ([^\s]+) /, message) ->
        match |> Enum.at(1) |> short_module()

      mfa = Map.get(metadata, :mfa) ->
        format_mfa(mfa)

      pid = Map.get(metadata, :pid) ->
        inspect(pid)

      true ->
        ""
    end
  end

  defp summarize(message) do
    cond do
      match = Regex.run(~r/Executing ([^\s]+) with params: (.*)/s, message) ->
        module = match |> Enum.at(1) |> short_module()
        params = match |> Enum.at(2) |> compact()
        shorten("#{module} #{params}", 180)

      match = Regex.run(~r/AgentServer ([^\s]+) spawned child ([^\s]+)/, message) ->
        "#{Enum.at(match, 1)} -> #{Enum.at(match, 2)}"

      true ->
        message |> compact() |> shorten(180)
    end
  end

  defp short_module(module) do
    module
    |> String.split(".")
    |> Enum.take(-2)
    |> Enum.join(".")
  end

  defp format_mfa({module, function, arity}), do: "#{inspect(module)}.#{function}/#{arity}"
  defp format_mfa(other), do: inspect(other)

  defp compact(message) do
    message
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp shorten(message, max_length) do
    if String.length(message) <= max_length do
      message
    else
      String.slice(message, 0, max_length - 1) <> "..."
    end
  end

  defp infer_keys([]), do: []

  defp infer_keys([%{} = row | _rows]) do
    row
    |> Map.keys()
    |> Enum.sort()
  end

  defp markdown_table(_rows, label, []), do: "### #{escape_markdown(label)}\n\n_No rows._"

  defp markdown_table(rows, label, keys) do
    headers =
      keys
      |> Enum.map(&header/1)
      |> Enum.join(" | ")

    separator =
      keys
      |> Enum.map(fn _key -> "---" end)
      |> Enum.join(" | ")

    body =
      rows
      |> Enum.map(fn row ->
        keys
        |> Enum.map(fn key -> row |> Map.get(key, "") |> table_cell() end)
        |> Enum.join(" | ")
      end)
      |> Enum.join("\n")

    "### #{escape_markdown(label)}\n\n| #{headers} |\n| #{separator} |\n#{body_rows(body)}"
  end

  defp body_rows(""), do: ""
  defp body_rows(body), do: "| #{body} |"

  defp header(key) do
    key
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
    |> escape_table_cell()
  end

  defp table_cell(value) when is_binary(value), do: escape_table_cell(value)
  defp table_cell(value), do: value |> inspect() |> escape_table_cell()

  defp escape_markdown(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("#", "\\#")
  end

  defp escape_table_cell(value) do
    value
    |> compact()
    |> shorten(220)
    |> String.replace("\\", "\\\\")
    |> String.replace("|", "\\|")
  end
end
