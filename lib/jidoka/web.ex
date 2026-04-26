defmodule Jidoka.Web do
  @moduledoc """
  Low-risk web capability for Jidoka agents.

  `Jidoka.Web` intentionally exposes a small, read-only subset of
  `jido_browser`: search, page reading, and page snapshots. It does not expose
  click, type, JavaScript evaluation, session state, tabs, or arbitrary browser
  control through the public Jidoka DSL.
  """

  @type mode :: :search | :read_only

  @type t :: %__MODULE__{
          mode: mode(),
          tools: [module()]
        }

  @enforce_keys [:mode, :tools]
  defstruct [:mode, :tools]

  @modes [:search, :read_only]
  @search_tools [Jidoka.Web.Tools.SearchWeb]
  @read_only_tools [
    Jidoka.Web.Tools.SearchWeb,
    Jidoka.Web.Tools.ReadPage,
    Jidoka.Web.Tools.SnapshotUrl
  ]
  @max_results 5
  @max_content_chars 12_000
  @blocked_hosts MapSet.new(["localhost", "0.0.0.0", "127.0.0.1", "::1"])

  @doc """
  Returns the supported web capability modes.
  """
  @spec modes() :: [mode()]
  def modes, do: @modes

  @doc """
  Returns the default maximum search results exposed to agent tools.
  """
  @spec max_results() :: pos_integer()
  def max_results, do: @max_results

  @doc """
  Returns the default maximum extracted page content characters.
  """
  @spec max_content_chars() :: pos_integer()
  def max_content_chars, do: @max_content_chars

  @doc """
  Builds a web capability config.
  """
  @spec new(term()) :: {:ok, t()} | {:error, String.t()}
  def new(mode) do
    with {:ok, normalized_mode} <- normalize_mode(mode) do
      {:ok, %__MODULE__{mode: normalized_mode, tools: tools_for(normalized_mode)}}
    end
  end

  @doc false
  @spec normalize_dsl([struct()]) :: {:ok, [t()]} | {:error, String.t()}
  def normalize_dsl(entries) when is_list(entries) do
    entries
    |> Enum.map(& &1.mode)
    |> normalize_entries()
  end

  @doc false
  @spec normalize_imported([term()]) :: {:ok, [t()]} | {:error, String.t()}
  def normalize_imported(entries) when is_list(entries) do
    entries
    |> Enum.map(&imported_mode/1)
    |> normalize_entries()
  end

  def normalize_imported(other),
    do: {:error, "web capabilities must be a list, got: #{inspect(other)}"}

  @doc false
  @spec normalize_imported_specs([term()]) :: [map()]
  def normalize_imported_specs(entries) when is_list(entries) do
    Enum.map(entries, fn
      entry when is_binary(entry) -> %{mode: entry}
      %{mode: _mode} = entry -> entry
      %{"mode" => _mode} = entry -> entry
      entry -> %{mode: entry}
    end)
  end

  @doc """
  Returns all tool modules for a list of web capabilities.
  """
  @spec tool_modules([t()]) :: [module()]
  def tool_modules(web_capabilities) when is_list(web_capabilities) do
    web_capabilities
    |> Enum.flat_map(& &1.tools)
    |> Enum.uniq()
  end

  @doc """
  Returns published tool names for web capabilities.
  """
  @spec tool_names([t()]) :: {:ok, [String.t()]} | {:error, String.t()}
  def tool_names(web_capabilities) when is_list(web_capabilities) do
    web_capabilities
    |> tool_modules()
    |> Jidoka.Tool.tool_names()
  end

  @doc false
  @spec clamp_search_results(term()) :: pos_integer()
  def clamp_search_results(value) when is_integer(value) do
    value
    |> max(1)
    |> min(@max_results)
  end

  def clamp_search_results(_value), do: @max_results

  @doc false
  @spec clamp_content_chars(term()) :: pos_integer()
  def clamp_content_chars(value) when is_integer(value) do
    value
    |> max(1)
    |> min(@max_content_chars)
  end

  def clamp_content_chars(_value), do: @max_content_chars

  @doc false
  @spec truncate_content(map(), pos_integer()) :: map()
  def truncate_content(%{} = result, max_chars) do
    result
    |> Map.update(:content, nil, &truncate_text(&1, max_chars))
    |> Map.update("content", nil, &truncate_text(&1, max_chars))
  end

  defp truncate_text(content, max_chars) when is_binary(content) do
    if String.length(content) > max_chars do
      String.slice(content, 0, max_chars) <> "\n\n[Content truncated by Jidoka.Web.]"
    else
      content
    end
  end

  defp truncate_text(content, _max_chars), do: content

  @doc false
  @spec validate_public_url(term()) :: :ok | {:error, Exception.t()}
  def validate_public_url(url) when is_binary(url) do
    uri = URI.parse(String.trim(url))

    cond do
      uri.scheme not in ["http", "https"] ->
        invalid_url(url, "URL must use http or https.")

      is_nil(uri.host) or String.trim(uri.host) == "" ->
        invalid_url(url, "URL must include a host.")

      blocked_host?(uri.host) ->
        invalid_url(url, "Local, loopback, and private network URLs are not allowed.")

      true ->
        :ok
    end
  end

  def validate_public_url(url), do: invalid_url(url, "URL must be a string.")

  @doc false
  @spec normalize_browser_error(atom(), term()) :: Exception.t()
  def normalize_browser_error(operation, reason) do
    Jidoka.Error.execution_error("Web #{operation} failed.",
      phase: :web,
      details: %{
        operation: operation,
        target: :jido_browser,
        cause: reason
      }
    )
  end

  defp normalize_entries([]), do: {:ok, []}

  defp normalize_entries(entries) do
    if length(entries) > 1 do
      {:error, "declare at most one web capability per Jidoka agent"}
    else
      entries
      |> Enum.reduce_while({:ok, []}, fn mode, {:ok, acc} ->
        case new(mode) do
          {:ok, web} -> {:cont, {:ok, acc ++ [web]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp normalize_mode(mode) when is_atom(mode) and mode in @modes, do: {:ok, mode}

  defp normalize_mode(mode) when is_binary(mode) do
    mode
    |> String.trim()
    |> case do
      "search" -> {:ok, :search}
      "read_only" -> {:ok, :read_only}
      other -> {:error, invalid_mode_message(other)}
    end
  end

  defp normalize_mode(mode), do: {:error, invalid_mode_message(mode)}

  defp invalid_mode_message(mode) do
    "web capability mode must be :search or :read_only, got: #{inspect(mode)}"
  end

  defp imported_mode(%{mode: mode}), do: mode
  defp imported_mode(%{"mode" => mode}), do: mode
  defp imported_mode(mode), do: mode

  defp tools_for(:search), do: @search_tools
  defp tools_for(:read_only), do: @read_only_tools

  defp invalid_url(url, message) do
    {:error,
     Jidoka.Error.validation_error(message,
       field: :url,
       value: url,
       details: %{operation: :web, reason: :invalid_url, cause: url}
     )}
  end

  defp blocked_host?(host) when is_binary(host) do
    normalized =
      host
      |> String.trim()
      |> String.trim_trailing(".")
      |> String.downcase()

    MapSet.member?(@blocked_hosts, normalized) or
      String.ends_with?(normalized, ".localhost") or
      private_ipv4?(normalized) or
      private_ipv6?(normalized)
  end

  defp private_ipv4?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, address} when tuple_size(address) == 4 -> private_ipv4_address?(address)
      _ -> false
    end
  end

  defp private_ipv6?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, {0, 0, 0, 0, 0, 0, 0, 0}} ->
        true

      {:ok, {0, 0, 0, 0, 0, 0, 0, 1}} ->
        true

      {:ok, {0, 0, 0, 0, 0, ipv4_marker, high, low}} when ipv4_marker in [0, 0xFFFF] ->
        {a, b, c, d} = ipv4_octets(high, low)
        private_ipv4_address?({a, b, c, d})

      {:ok, {first, _, _, _, _, _, _, _}} when first >= 0xFC00 and first <= 0xFDFF ->
        true

      {:ok, {first, _, _, _, _, _, _, _}} when first >= 0xFE80 and first <= 0xFEFF ->
        true

      {:ok, {first, _, _, _, _, _, _, _}} when first >= 0xFF00 and first <= 0xFFFF ->
        true

      _ ->
        false
    end
  end

  defp private_ipv4_address?({10, _, _, _}), do: true
  defp private_ipv4_address?({127, _, _, _}), do: true
  defp private_ipv4_address?({169, 254, _, _}), do: true
  defp private_ipv4_address?({172, second, _, _}) when second >= 16 and second <= 31, do: true
  defp private_ipv4_address?({192, 168, _, _}), do: true
  defp private_ipv4_address?({0, _, _, _}), do: true
  defp private_ipv4_address?(_address), do: false

  defp ipv4_octets(high, low) do
    {div(high, 256), rem(high, 256), div(low, 256), rem(low, 256)}
  end
end
