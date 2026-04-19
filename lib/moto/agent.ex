defmodule Moto.Agent do
  @moduledoc """
  Thin Spark-backed wrapper around `Jido.AI.Agent` for Moto.

  This first DSL is intentionally tiny:

      defmodule MyApp.ChatAgent do
        use Moto.Agent

        agent do
          name "chat_agent"
          system_prompt "You are a concise assistant."
        end
      end

  Only `name` and `system_prompt` are supported. A nested runtime module is
  generated automatically and uses `Jido.AI.Agent` with `model: :fast` and
  `tools: []`.
  """

  defmacro __using__(opts \\ []) do
    if opts != [] do
      raise CompileError,
        file: __CALLER__.file,
        line: __CALLER__.line,
        description:
          "Moto.Agent now uses a Spark DSL. Use `use Moto.Agent` and configure it inside `agent do ... end`."
    end

    quote location: :keep do
      use Moto.Agent.SparkDsl

      @before_compile Moto.Agent
    end
  end

  defmacro __before_compile__(env) do
    default_name =
      env.module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()

    name = Spark.Dsl.Extension.get_opt(env.module, [:agent], :name, default_name)
    system_prompt = Spark.Dsl.Extension.get_opt(env.module, [:agent], :system_prompt)
    runtime_module = Module.concat(env.module, Runtime)

    if is_nil(system_prompt) do
      raise CompileError,
        file: env.file,
        line: env.line,
        description: "Moto.Agent requires `system_prompt` inside `agent do ... end`."
    end

    quote location: :keep do
      defmodule unquote(runtime_module) do
        use Jido.AI.Agent,
          name: unquote(name),
          system_prompt: unquote(system_prompt),
          model: :fast,
          tools: []
      end

      @doc """
      Starts this agent under the shared `Moto.Runtime` instance.
      """
      @spec start_link(keyword()) :: DynamicSupervisor.on_start_child()
      def start_link(opts \\ []) do
        Moto.start_agent(unquote(runtime_module), opts)
      end

      @doc """
      Convenience alias for `ask_sync/3`.
      """
      @spec chat(pid(), String.t(), keyword()) :: {:ok, term()} | {:error, term()}
      def chat(pid, message, opts \\ []) when is_pid(pid) and is_binary(message) do
        unquote(runtime_module).ask_sync(pid, message, opts)
      end

      @doc """
      Returns the generated runtime module used internally by Moto.
      """
      @spec runtime_module() :: module()
      def runtime_module, do: unquote(runtime_module)

      @doc """
      Returns the configured public agent name.
      """
      @spec name() :: String.t()
      def name, do: unquote(name)

      @doc """
      Returns the configured system prompt.
      """
      @spec system_prompt() :: String.t()
      def system_prompt, do: unquote(system_prompt)
    end
  end
end
