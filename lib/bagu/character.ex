defmodule Bagu.Character do
  @moduledoc """
  Character rendering support for Bagu agents.

  Characters are structured persona inputs that render into the effective
  system prompt. Bagu keeps them separate from tools, memory, workflows, and
  handoffs: a character shapes how an agent speaks and behaves, while
  `defaults.instructions` remains the explicit task and policy layer.
  """

  @context_key :__bagu_character__

  @typedoc "Runtime request data available to dynamic character renderers."
  @type input :: Bagu.Agent.SystemPrompt.input()

  @typedoc "A character source accepted by Bagu."
  @type source :: :none | String.t() | map() | struct() | module() | {module(), atom(), [term()]}

  @typedoc "Normalized character prompt source."
  @type spec :: nil | :none | {:static, String.t()} | {:dynamic, source()}
  @type registry :: %{required(String.t()) => source()}

  @callback render_character(input()) :: String.t() | map() | {:ok, String.t() | map()} | {:error, term()}

  @doc """
  Internal runtime-context key used for per-request character overrides.
  """
  @spec context_key() :: atom()
  def context_key, do: @context_key

  @doc """
  Normalizes a compile-time or runtime character source.
  """
  @spec normalize(module() | nil, term(), keyword()) :: {:ok, spec()} | {:error, String.t()}
  def normalize(owner_module, character, opts \\ [])

  def normalize(_owner_module, nil, _opts), do: {:ok, nil}
  def normalize(_owner_module, :none, _opts), do: {:ok, :none}

  def normalize(_owner_module, character, opts) when is_binary(character) do
    case String.trim(character) do
      "" -> {:error, "#{label(opts)} must not be empty"}
      prompt -> {:ok, {:static, prompt}}
    end
  end

  def normalize(_owner_module, %_{} = character, opts) do
    normalize_map_character(character, opts)
  end

  def normalize(_owner_module, character, opts) when is_map(character) do
    normalize_map_character(character, opts)
  end

  def normalize(_owner_module, {module, function, args} = spec, opts)
      when is_atom(module) and is_atom(function) and is_list(args) do
    case Code.ensure_compiled(module) do
      {:module, ^module} ->
        arity = length(args) + 1

        if function_exported?(module, function, arity) do
          {:ok, {:dynamic, spec}}
        else
          {:error, "#{label(opts)} MFA #{inspect(spec)} must export #{function}/#{arity} on #{inspect(module)}"}
        end

      {:error, reason} ->
        {:error, "#{label(opts)} module #{inspect(module)} could not be loaded: #{inspect(reason)}"}
    end
  end

  def normalize(_owner_module, module, opts) when is_atom(module) do
    case Code.ensure_compiled(module) do
      {:module, ^module} ->
        if renderable_module?(module) do
          {:ok, {:dynamic, module}}
        else
          {:error,
           "#{label(opts)} module #{inspect(module)} must implement render_character/1, to_system_prompt/0, character/0, or new/0 with to_system_prompt/1"}
        end

      {:error, reason} ->
        {:error, "#{label(opts)} module #{inspect(module)} could not be loaded: #{inspect(reason)}"}
    end
  end

  def normalize(_owner_module, other, opts) do
    {:error, "#{label(opts)} must be a string, map, module, MFA tuple, or :none, got: #{inspect(other)}"}
  end

  @doc """
  Resolves a normalized character source into prompt text.
  """
  @spec resolve(spec(), input()) :: {:ok, String.t() | nil} | {:error, term()}
  def resolve(character, input)

  def resolve(nil, _input), do: {:ok, nil}
  def resolve(:none, _input), do: {:ok, nil}
  def resolve({:static, prompt}, _input) when is_binary(prompt), do: {:ok, prompt}
  def resolve({:dynamic, character}, input), do: render(character, input)
  def resolve(character, input), do: render(character, input)

  @doc """
  Resolves a request-level character override from runtime context.
  """
  @spec runtime_override(map()) :: spec() | nil
  def runtime_override(context) when is_map(context), do: Map.get(context, @context_key)
  def runtime_override(_context), do: nil

  @doc false
  @spec normalize_available_characters(registry() | keyword()) :: {:ok, registry()} | {:error, String.t()}
  def normalize_available_characters(characters) when is_list(characters) do
    characters
    |> Enum.into(%{})
    |> normalize_available_characters()
  rescue
    _ -> {:error, "available_characters must be a map of character name => character source"}
  end

  def normalize_available_characters(characters) when is_map(characters) do
    characters
    |> Enum.reduce_while({:ok, %{}}, fn {name, source}, {:ok, acc} ->
      with {:ok, name} <- normalize_registry_name(name),
           :ok <- ensure_unique_registry_name(name, acc),
           {:ok, _spec} <- normalize(nil, source, label: "available character #{inspect(name)}") do
        {:cont, {:ok, Map.put(acc, name, source)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  def normalize_available_characters(_characters),
    do: {:error, "available_characters must be a map of character name => character source"}

  @doc false
  @spec resolve_character_name(String.t(), registry()) :: {:ok, source()} | {:error, String.t()}
  def resolve_character_name(name, registry) when is_binary(name) and is_map(registry) do
    case Map.fetch(registry, name) do
      {:ok, source} -> {:ok, source}
      :error -> {:error, "unknown character #{inspect(name)}"}
    end
  end

  def resolve_character_name(_name, _registry),
    do: {:error, "character name must be a string and registry must be a map"}

  defp normalize_map_character(character, opts) do
    case render(character, empty_input()) do
      {:ok, prompt} -> {:ok, {:static, prompt}}
      {:error, reason} -> {:error, "#{label(opts)} could not be rendered: #{inspect(reason)}"}
    end
  end

  defp render(character, _input) when is_binary(character) do
    case String.trim(character) do
      "" -> {:error, "character prompt must not be empty"}
      prompt -> {:ok, prompt}
    end
  end

  defp render(%_{} = character, input), do: render_map_or_struct(character, input)
  defp render(character, input) when is_map(character), do: render_map_or_struct(character, input)

  defp render({module, function, args}, input) do
    module
    |> apply(function, [input | args])
    |> normalize_render_result(input, {module, function, length(args) + 1})
  rescue
    error ->
      {:error, "character MFA #{inspect(module)}.#{function}/#{length(args) + 1} failed: #{Exception.message(error)}"}
  end

  defp render(module, input) when is_atom(module) do
    with {:module, ^module} <- Code.ensure_loaded(module) do
      render_loaded_module(module, input)
    else
      {:error, reason} -> {:error, "character module #{inspect(module)} could not be loaded: #{inspect(reason)}"}
    end
  rescue
    error ->
      {:error, "character module #{inspect(module)} failed: #{Exception.message(error)}"}
  end

  defp render(other, _input), do: {:error, "unsupported character source #{inspect(other)}"}

  defp render_loaded_module(module, input) do
    cond do
      function_exported?(module, :render_character, 1) ->
        module
        |> apply(:render_character, [input])
        |> normalize_render_result(input, module)

      function_exported?(module, :to_system_prompt, 0) ->
        module
        |> apply(:to_system_prompt, [])
        |> normalize_render_result(input, module)

      function_exported?(module, :character, 0) ->
        module
        |> apply(:character, [])
        |> normalize_render_result(input, module)

      function_exported?(module, :new, 0) and function_exported?(module, :to_system_prompt, 1) ->
        with {:ok, character} <- normalize_new_result(apply(module, :new, [])) do
          module
          |> apply(:to_system_prompt, [character])
          |> normalize_render_result(input, module)
        end

      function_exported?(module, :new, 0) and function_exported?(module, :to_system_prompt, 2) ->
        with {:ok, character} <- normalize_new_result(apply(module, :new, [])) do
          module
          |> apply(:to_system_prompt, [character, []])
          |> normalize_render_result(input, module)
        end

      true ->
        {:error, "character module #{inspect(module)} is not renderable"}
    end
  end

  defp render_map_or_struct(character, input) do
    character_map = if is_struct(character), do: Map.from_struct(character), else: character

    case maybe_jido_character_prompt(character_map) do
      {:ok, prompt} -> {:ok, prompt}
      :error -> render_bagu_character_map(character_map, input)
    end
  end

  defp normalize_render_result({:ok, result}, input, resolver), do: normalize_render_result(result, input, resolver)
  defp normalize_render_result({:error, reason}, _input, _resolver), do: {:error, reason}
  defp normalize_render_result(result, input, _resolver), do: render(result, input)

  defp normalize_new_result({:ok, character}), do: {:ok, character}
  defp normalize_new_result(character) when is_map(character), do: {:ok, character}
  defp normalize_new_result(other), do: {:error, "character new/0 returned #{inspect(other)}"}

  defp renderable_module?(module) do
    function_exported?(module, :render_character, 1) or
      function_exported?(module, :to_system_prompt, 0) or
      function_exported?(module, :character, 0) or
      (function_exported?(module, :new, 0) and
         (function_exported?(module, :to_system_prompt, 1) or function_exported?(module, :to_system_prompt, 2)))
  end

  defp maybe_jido_character_prompt(character) when is_map(character) do
    with {:module, Jido.Character} <- Code.ensure_loaded(Jido.Character),
         true <- function_exported?(Jido.Character, :new, 1),
         {:ok, parsed} <- apply(Jido.Character, :new, [character]),
         {:ok, prompt} <- jido_character_to_prompt(parsed) do
      {:ok, prompt}
    else
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp jido_character_to_prompt(character) do
    cond do
      function_exported?(Jido.Character, :to_system_prompt, 1) ->
        {:ok, apply(Jido.Character, :to_system_prompt, [character])}

      function_exported?(Jido.Character, :to_system_prompt, 2) ->
        {:ok, apply(Jido.Character, :to_system_prompt, [character, []])}

      true ->
        :error
    end
  end

  defp render_bagu_character_map(character, _input) do
    sections =
      [
        base_section(character),
        identity_section(get_key(character, :identity)),
        personality_section(get_key(character, :personality)),
        voice_section(get_key(character, :voice)),
        list_section("Knowledge", get_key(character, :knowledge)),
        memory_section(get_key(character, :memory)),
        list_section("Character Instructions", get_key(character, :instructions))
      ]
      |> Enum.reject(&is_nil/1)

    case sections do
      [] -> {:error, "character map does not contain renderable fields"}
      _ -> {:ok, Enum.join(sections, "\n\n")}
    end
  end

  defp base_section(character) do
    lines =
      [
        text_line("Name", get_key(character, :name)),
        text_line("Description", get_key(character, :description))
      ]
      |> Enum.reject(&is_nil/1)

    section("Character", lines)
  end

  defp identity_section(nil), do: nil

  defp identity_section(identity) when is_map(identity) do
    lines =
      [
        text_line("Role", get_key(identity, :role)),
        text_line("Background", get_key(identity, :background)),
        text_line("Age", get_key(identity, :age)),
        list_line("Facts", get_key(identity, :facts))
      ]
      |> Enum.reject(&is_nil/1)

    section("Identity", lines)
  end

  defp identity_section(identity), do: section("Identity", [to_string(identity)])

  defp personality_section(nil), do: nil

  defp personality_section(personality) when is_map(personality) do
    lines =
      [
        list_line("Traits", get_key(personality, :traits)),
        list_line("Values", get_key(personality, :values)),
        list_line("Quirks", get_key(personality, :quirks))
      ]
      |> Enum.reject(&is_nil/1)

    section("Personality", lines)
  end

  defp personality_section(personality), do: section("Personality", [to_string(personality)])

  defp voice_section(nil), do: nil

  defp voice_section(voice) when is_map(voice) do
    lines =
      [
        text_line("Tone", get_key(voice, :tone)),
        text_line("Style", get_key(voice, :style)),
        text_line("Vocabulary", get_key(voice, :vocabulary)),
        list_line("Expressions", get_key(voice, :expressions))
      ]
      |> Enum.reject(&is_nil/1)

    section("Voice", lines)
  end

  defp voice_section(voice), do: section("Voice", [to_string(voice)])

  defp memory_section(nil), do: nil
  defp memory_section(%{entries: entries}), do: list_section("Character Memory", entries)
  defp memory_section(%{"entries" => entries}), do: list_section("Character Memory", entries)
  defp memory_section(memory), do: list_section("Character Memory", memory)

  defp list_section(_title, nil), do: nil

  defp list_section(title, value) do
    value
    |> normalize_list()
    |> Enum.map(&format_item/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> nil
      items -> section(title, Enum.map(items, &"- #{&1}"))
    end
  end

  defp section(_title, []), do: nil
  defp section(title, lines), do: Enum.join([title | lines], "\n")

  defp text_line(_label, nil), do: nil
  defp text_line(_label, ""), do: nil
  defp text_line(label, value), do: "#{label}: #{format_item(value)}"

  defp list_line(_label, nil), do: nil

  defp list_line(label, value) do
    value
    |> normalize_list()
    |> Enum.map(&format_item/1)
    |> Enum.reject(&(&1 == ""))
    |> case do
      [] -> nil
      items -> "#{label}: #{Enum.join(items, ", ")}"
    end
  end

  defp normalize_list(value) when is_list(value), do: value
  defp normalize_list(value), do: [value]

  defp format_item(%{} = item) do
    cond do
      content = get_key(item, :content) -> to_string(content)
      name = get_key(item, :name) -> to_string(name)
      true -> inspect(item)
    end
  end

  defp format_item(value) when is_atom(value), do: Atom.to_string(value)
  defp format_item(value), do: to_string(value)

  defp get_key(map, key) when is_map(map) do
    Map.get(map, key, Map.get(map, Atom.to_string(key)))
  end

  defp label(opts), do: Keyword.get(opts, :label, "character")

  defp empty_input do
    %{request: %{}, state: nil, config: nil, context: %{}}
  end

  defp normalize_registry_name(name) when is_atom(name), do: normalize_registry_name(Atom.to_string(name))

  defp normalize_registry_name(name) when is_binary(name) do
    case String.trim(name) do
      "" -> {:error, "character registry keys must not be empty"}
      normalized -> {:ok, normalized}
    end
  end

  defp normalize_registry_name(_name), do: {:error, "character registry keys must be strings or atoms"}

  defp ensure_unique_registry_name(name, registry) do
    if Map.has_key?(registry, name) do
      {:error, "duplicate character #{inspect(name)} in available_characters"}
    else
      :ok
    end
  end
end
