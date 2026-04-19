defmodule Moto.Guardrails do
  @moduledoc false

  alias Jido.AI.Request
  alias Jido.AI.Signal.LLMResponse
  alias Moto.Interrupt

  @request_guardrails_key :__moto_guardrails__
  @tool_guardrail_callback_key :__tool_guardrail_callback__
  @stages [:input, :output, :tool]
  @guardrail_timeout_ms 5_000

  defmodule Input do
    @moduledoc false
    @enforce_keys [
      :agent,
      :server,
      :request_id,
      :message,
      :context,
      :allowed_tools,
      :llm_opts,
      :metadata,
      :request_opts
    ]
    defstruct [
      :agent,
      :server,
      :request_id,
      :message,
      :context,
      :allowed_tools,
      :llm_opts,
      :metadata,
      :request_opts
    ]
  end

  defmodule Output do
    @moduledoc false
    @enforce_keys [
      :agent,
      :server,
      :request_id,
      :message,
      :context,
      :allowed_tools,
      :llm_opts,
      :metadata,
      :request_opts,
      :outcome
    ]
    defstruct [
      :agent,
      :server,
      :request_id,
      :message,
      :context,
      :allowed_tools,
      :llm_opts,
      :metadata,
      :request_opts,
      :outcome
    ]
  end

  defmodule Tool do
    @moduledoc false
    @enforce_keys [
      :agent,
      :server,
      :request_id,
      :tool_name,
      :arguments,
      :context,
      :metadata,
      :request_opts
    ]
    defstruct [
      :agent,
      :server,
      :request_id,
      :tool_name,
      :tool_call_id,
      :arguments,
      :context,
      :metadata,
      :request_opts
    ]
  end

  @type stage :: :input | :output | :tool
  @type guardrail_ref ::
          module()
          | {module(), atom(), [term()]}
          | (term() -> :ok | {:error, term()} | {:interrupt, term()})
  @type stage_map :: %{
          input: [guardrail_ref()],
          output: [guardrail_ref()],
          tool: [guardrail_ref()]
        }

  @spec default_stage_map() :: stage_map()
  def default_stage_map do
    %{input: [], output: [], tool: []}
  end

  @spec prepare_request_opts(keyword()) :: {:ok, keyword()} | {:error, term()}
  def prepare_request_opts(opts) when is_list(opts) do
    with {:ok, guardrails} <- normalize_request_guardrails(Keyword.get(opts, :guardrails, nil)) do
      context = Keyword.get(opts, :tool_context, %{}) || %{}

      opts =
        opts
        |> Keyword.delete(:guardrails)
        |> Keyword.put(:tool_context, maybe_attach_request_guardrails(context, guardrails))

      {:ok, opts}
    end
  end

  @spec normalize_dsl_guardrails(stage_map()) :: {:ok, stage_map()} | {:error, String.t()}
  def normalize_dsl_guardrails(guardrails) when is_map(guardrails) do
    Enum.reduce_while(@stages, {:ok, default_stage_map()}, fn stage, {:ok, acc} ->
      case normalize_stage_list(Map.get(guardrails, stage, []), stage, :dsl) do
        {:ok, normalized} -> {:cont, {:ok, Map.put(acc, stage, normalized)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  @spec normalize_request_guardrails(term()) :: {:ok, stage_map()} | {:error, term()}
  def normalize_request_guardrails(nil), do: {:ok, default_stage_map()}

  def normalize_request_guardrails(guardrails) when is_list(guardrails) or is_map(guardrails) do
    guardrails
    |> Map.new()
    |> normalize_stage_map(:runtime)
  end

  def normalize_request_guardrails(other),
    do:
      {:error,
       {:invalid_guardrail_spec,
        "guardrails must be a keyword list or map, got: #{inspect(other)}"}}

  @spec validate_dsl_guardrail_ref(stage(), term()) :: :ok | {:error, String.t()}
  def validate_dsl_guardrail_ref(stage, ref) when stage in @stages do
    case normalize_stage_ref(ref, stage, :dsl) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @spec on_before_cmd(Jido.Agent.t(), term(), stage_map()) :: {:ok, Jido.Agent.t(), term()}
  def on_before_cmd(agent, {:ai_react_start, %{query: query} = params}, defaults) do
    request_id = params[:request_id] || agent.state[:last_request_id]
    {request_guardrails, params} = pop_request_guardrails(params)
    guardrails = combine(defaults, request_guardrails)
    context = Map.get(params, :tool_context, %{}) || %{}

    input = %Input{
      agent: agent,
      server: self(),
      request_id: request_id,
      message: query,
      context: context,
      allowed_tools: Map.get(params, :allowed_tools),
      llm_opts: Map.get(params, :llm_opts, []),
      metadata: %{},
      request_opts: params
    }

    guardrail_meta = %{
      guardrails: guardrails,
      message: input.message,
      context: input.context,
      allowed_tools: input.allowed_tools,
      llm_opts: input.llm_opts,
      request_opts: input.request_opts,
      metadata: input.metadata
    }

    case run_input(guardrails.input, input) do
      :ok ->
        params =
          Map.update(params, :tool_context, %{}, fn tool_context ->
            tool_context
            |> Kernel.||(%{})
            |> maybe_attach_tool_guardrail_callback(guardrails.tool, agent, request_id)
          end)

        {:ok, put_request_guardrail_meta(agent, request_id, guardrail_meta),
         {:ai_react_start, params}}

      {:error, label, reason} ->
        error = {:guardrail, :input, label, reason}

        agent =
          agent
          |> Request.fail_request(request_id, error)
          |> put_request_guardrail_meta(request_id, Map.put(guardrail_meta, :error, error))

        {:ok, agent, Jido.Actions.Control.Noop}

      {:interrupt, label, %Interrupt{} = interrupt} ->
        agent =
          agent
          |> Request.fail_request(request_id, {:interrupt, interrupt})
          |> put_request_guardrail_meta(
            request_id,
            guardrail_meta
            |> Map.put(:interrupt, interrupt)
            |> Map.put(:interrupt_guardrail, label)
          )

        Moto.Hooks.notify_interrupt(agent, request_id, interrupt)
        {:ok, agent, Jido.Actions.Control.Noop}
    end
  end

  def on_before_cmd(agent, action, _defaults), do: {:ok, agent, action}

  @spec on_after_cmd(Jido.Agent.t(), term(), [term()], stage_map()) ::
          {:ok, Jido.Agent.t(), [term()]}
  def on_after_cmd(agent, {:ai_react_start, %{request_id: request_id}}, directives, _defaults) do
    run_output_guardrails(agent, request_id, directives)
  end

  def on_after_cmd(agent, _action, directives, _defaults) do
    run_output_guardrails(agent, agent.state[:last_request_id], directives)
  end

  @spec combine(stage_map(), stage_map()) :: stage_map()
  def combine(defaults, request_guardrails) do
    %{
      input: Map.get(defaults, :input, []) ++ Map.get(request_guardrails, :input, []),
      output: Map.get(defaults, :output, []) ++ Map.get(request_guardrails, :output, []),
      tool: Map.get(defaults, :tool, []) ++ Map.get(request_guardrails, :tool, [])
    }
  end

  @spec tool_signal_override(Jido.Signal.t(), Jido.Agent.t()) ::
          :continue
          | {:override,
             %{
               request_id: String.t(),
               guardrail_label: String.t(),
               reason: term(),
               message: String.t(),
               interrupt: Interrupt.t() | nil
             }}
  def tool_signal_override(signal, agent) do
    request_id = signal_request_id(signal)
    tool_calls = LLMResponse.extract_tool_calls(signal)

    with true <- is_binary(request_id) and request_id != "",
         [_ | _] <- tool_calls,
         %{} = meta <- get_request_guardrail_meta(agent, request_id),
         [_ | _] = tool_guardrails <- get_in(meta, [:guardrails, :tool]) do
      Enum.reduce_while(tool_calls, :continue, fn tool_call, _acc ->
        input = %Tool{
          agent: agent,
          server: self(),
          request_id: request_id,
          tool_name: tool_call_name(tool_call),
          tool_call_id: tool_call_id(tool_call),
          arguments: tool_call_arguments(tool_call),
          context: meta[:context] || %{},
          metadata: meta[:metadata] || %{},
          request_opts: meta[:request_opts] || %{}
        }

        case run_tool(tool_guardrails, input) do
          :ok ->
            {:cont, :continue}

          {:error, label, reason} ->
            {:halt,
             {:override,
              %{
                request_id: request_id,
                guardrail_label: label,
                reason: reason,
                message:
                  "Tool call #{inspect(input.tool_name)} blocked by guardrail #{inspect(label)}",
                interrupt: nil
              }}}

          {:interrupt, label, %Interrupt{} = interrupt} ->
            {:halt,
             {:override,
              %{
                request_id: request_id,
                guardrail_label: label,
                reason: :interrupt,
                message:
                  "Tool call #{inspect(input.tool_name)} interrupted by guardrail #{inspect(label)}",
                interrupt: interrupt
              }}}
        end
      end)
    else
      _ -> :continue
    end
  end

  @spec maybe_run_tool_guardrails(map(), map()) ::
          :ok | {:error, term()} | {:interrupt, Interrupt.t()}
  def maybe_run_tool_guardrails(
        %{tool_name: _tool_name, arguments: _arguments} = tool_call,
        context
      )
      when is_map(context) do
    callback =
      Map.get(context, @tool_guardrail_callback_key) ||
        Map.get(context, Atom.to_string(@tool_guardrail_callback_key))

    case callback do
      fun when is_function(fun, 1) ->
        case fun.(tool_call) do
          :ok -> :ok
          {:error, reason} -> {:error, reason}
          {:interrupt, %Interrupt{} = interrupt} -> {:interrupt, interrupt}
          other -> {:error, {:invalid_tool_guardrail_result, other}}
        end

      _ ->
        :ok
    end
  rescue
    error ->
      {:error, {:tool_guardrail_callback_failed, Exception.message(error)}}
  end

  def maybe_run_tool_guardrails(_tool_call, _context), do: :ok

  defp normalize_stage_map(guardrails, mode) do
    Enum.reduce_while(Map.to_list(guardrails), {:ok, default_stage_map()}, fn {key, value},
                                                                              {:ok, acc} ->
      with {:ok, stage} <- normalize_stage_key(key),
           {:ok, normalized} <- normalize_stage_list(value, stage, mode) do
        {:cont, {:ok, Map.put(acc, stage, normalized)}}
      else
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp normalize_stage_key(stage) when stage in @stages, do: {:ok, stage}

  defp normalize_stage_key(stage) when is_binary(stage) do
    try do
      case String.to_existing_atom(stage) do
        stage_atom when stage_atom in @stages -> {:ok, stage_atom}
        other -> {:error, {:invalid_guardrail_stage, other}}
      end
    rescue
      ArgumentError -> {:error, {:invalid_guardrail_stage, stage}}
    end
  end

  defp normalize_stage_key(stage), do: {:error, {:invalid_guardrail_stage, stage}}

  defp normalize_stage_list(value, stage, mode) do
    refs =
      cond do
        value == [] -> []
        is_list(value) and not Keyword.keyword?(value) -> value
        value == nil -> []
        true -> [value]
      end

    Enum.reduce_while(refs, {:ok, []}, fn ref, {:ok, acc} ->
      case normalize_stage_ref(ref, stage, mode) do
        {:ok, normalized} -> {:cont, {:ok, acc ++ [normalized]}}
        {:error, reason} -> {:halt, {:error, wrap_invalid_ref(stage, reason)}}
      end
    end)
  end

  defp normalize_stage_ref(module, _stage, _mode) when is_atom(module) do
    case Moto.Guardrail.validate_guardrail_module(module) do
      :ok -> {:ok, module}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_stage_ref({module, function, args} = ref, _stage, _mode)
       when is_atom(module) and is_atom(function) and is_list(args) do
    case Code.ensure_compiled(module) do
      {:module, ^module} ->
        arity = length(args) + 1

        if function_exported?(module, function, arity) do
          {:ok, ref}
        else
          {:error,
           "guardrail MFA #{inspect(ref)} must export #{function}/#{arity} on #{inspect(module)}"}
        end

      {:error, reason} ->
        {:error, "guardrail module #{inspect(module)} could not be loaded: #{inspect(reason)}"}
    end
  end

  defp normalize_stage_ref(fun, _stage, :runtime) when is_function(fun, 1), do: {:ok, fun}

  defp normalize_stage_ref(fun, _stage, :dsl) when is_function(fun) do
    {:error,
     "DSL guardrails do not support anonymous functions; use a Moto.Guardrail module or MFA instead"}
  end

  defp normalize_stage_ref(other, _stage, _mode),
    do:
      {:error,
       "guardrail refs must be a Moto.Guardrail module, MFA tuple, or runtime function, got: #{inspect(other)}"}

  defp wrap_invalid_ref(stage, reason) when is_binary(reason),
    do: {:invalid_guardrail, stage, reason}

  defp wrap_invalid_ref(stage, reason), do: {:invalid_guardrail, stage, inspect(reason)}

  defp maybe_attach_request_guardrails(context, guardrails) do
    if guardrails == default_stage_map() do
      context
    else
      Map.put(context, @request_guardrails_key, guardrails)
    end
  end

  defp pop_request_guardrails(params) when is_map(params) do
    context = Map.get(params, :tool_context, %{}) || %{}
    {request_guardrails, context} = Map.pop(context, @request_guardrails_key, default_stage_map())
    {request_guardrails, Map.put(params, :tool_context, context)}
  end

  defp maybe_attach_tool_guardrail_callback(context, [], _agent, _request_id), do: context

  defp maybe_attach_tool_guardrail_callback(context, tool_guardrails, agent, request_id)
       when is_map(context) and is_binary(request_id) do
    callback = fn %{
                    tool_name: tool_name,
                    tool_call_id: tool_call_id,
                    arguments: arguments,
                    context: runtime_context
                  } ->
      input = %Tool{
        agent: agent,
        server: self(),
        request_id: request_id,
        tool_name: tool_name,
        tool_call_id: tool_call_id,
        arguments: arguments,
        context: runtime_context,
        metadata: %{},
        request_opts: %{}
      }

      case run_tool(tool_guardrails, input) do
        :ok ->
          :ok

        {:error, label, reason} ->
          {:error, {:guardrail, :tool, label, reason}}

        {:interrupt, _label, %Interrupt{} = interrupt} ->
          Moto.Hooks.notify_interrupt(agent, request_id, interrupt)
          {:interrupt, interrupt}
      end
    end

    Map.put(context, @tool_guardrail_callback_key, callback)
  end

  defp maybe_attach_tool_guardrail_callback(context, _tool_guardrails, _agent, _request_id),
    do: context

  defp run_input(guardrails, %Input{} = input) do
    Enum.reduce_while(guardrails, :ok, fn guardrail, :ok ->
      case invoke_guardrail(guardrail, input) do
        :ok ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, guardrail_label(guardrail), reason}}

        {:interrupt, interrupt} ->
          {:halt, {:interrupt, guardrail_label(guardrail), normalize_interrupt(interrupt)}}

        other ->
          {:halt, {:error, guardrail_label(guardrail), invalid_result_message(other)}}
      end
    end)
  end

  defp run_output(guardrails, %Output{} = input) do
    Enum.reduce_while(guardrails, :ok, fn guardrail, :ok ->
      case invoke_guardrail(guardrail, input) do
        :ok ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, guardrail_label(guardrail), reason}}

        {:interrupt, interrupt} ->
          {:halt, {:interrupt, guardrail_label(guardrail), normalize_interrupt(interrupt)}}

        other ->
          {:halt, {:error, guardrail_label(guardrail), invalid_result_message(other)}}
      end
    end)
  end

  defp run_tool(guardrails, %Tool{} = input) do
    Enum.reduce_while(guardrails, :ok, fn guardrail, :ok ->
      case invoke_guardrail(guardrail, input) do
        :ok ->
          {:cont, :ok}

        {:error, reason} ->
          {:halt, {:error, guardrail_label(guardrail), reason}}

        {:interrupt, interrupt} ->
          {:halt, {:interrupt, guardrail_label(guardrail), normalize_interrupt(interrupt)}}

        other ->
          {:halt, {:error, guardrail_label(guardrail), invalid_result_message(other)}}
      end
    end)
  end

  defp invalid_result_message(other) do
    "guardrails must return :ok, {:error, reason}, or {:interrupt, interrupt}; got: #{inspect(other)}"
  end

  defp guardrail_label(module) when is_atom(module) do
    case Moto.Guardrail.guardrail_name(module) do
      {:ok, name} -> name
      {:error, _reason} -> inspect(module)
    end
  end

  defp guardrail_label({module, function, args}),
    do: "#{inspect(module)}.#{function}/#{length(args) + 1}"

  defp guardrail_label(fun) when is_function(fun, 1), do: "anonymous_guardrail"

  defp invoke_guardrail(module, input) when is_atom(module) do
    invoke_with_timeout(fn -> module.call(input) end)
  end

  defp invoke_guardrail({module, function, args}, input) do
    invoke_with_timeout(fn -> apply(module, function, [input | args]) end)
  end

  defp invoke_guardrail(fun, input) when is_function(fun, 1) do
    invoke_with_timeout(fn -> fun.(input) end)
  end

  defp invoke_with_timeout(fun) do
    task = Task.async(fun)

    case Task.yield(task, @guardrail_timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
    end
  rescue
    error -> {:error, Exception.message(error)}
  end

  defp put_request_guardrail_meta(agent, request_id, guardrail_meta) do
    update_in(agent.state, [:requests, request_id], fn
      nil ->
        %{meta: %{moto_guardrails: guardrail_meta}}

      request ->
        meta =
          request
          |> Map.get(:meta, %{})
          |> Map.put(:moto_guardrails, guardrail_meta)

        Map.put(request, :meta, meta)
    end)
    |> then(&%{agent | state: &1})
  end

  defp get_request_guardrail_meta(agent, request_id) do
    get_in(agent.state, [:requests, request_id, :meta, :moto_guardrails])
  end

  defp run_output_guardrails(agent, request_id, directives) when is_binary(request_id) do
    case {get_request_guardrail_meta(agent, request_id), current_outcome(agent, request_id)} do
      {%{} = meta, outcome} when not is_nil(outcome) ->
        if Map.get(meta, :output_applied?, false) do
          {:ok, agent, directives}
        else
          input = %Output{
            agent: agent,
            server: self(),
            request_id: request_id,
            message: meta[:message] || "",
            context: meta[:context] || %{},
            allowed_tools: meta[:allowed_tools],
            llm_opts: meta[:llm_opts] || [],
            metadata: meta[:metadata] || %{},
            request_opts: meta[:request_opts] || %{},
            outcome: outcome
          }

          case run_output(get_in(meta, [:guardrails, :output]) || [], input) do
            :ok ->
              {:ok,
               put_request_guardrail_meta(
                 agent,
                 request_id,
                 Map.put(meta, :output_applied?, true)
               ), directives}

            {:error, label, reason} ->
              error = {:guardrail, :output, label, reason}

              agent =
                agent
                |> force_request_failure(request_id, error)
                |> put_request_guardrail_meta(
                  request_id,
                  meta
                  |> Map.put(:output_applied?, true)
                  |> Map.put(:error, error)
                )

              {:ok, agent, directives}

            {:interrupt, label, %Interrupt{} = interrupt} ->
              agent =
                agent
                |> force_request_failure(request_id, {:interrupt, interrupt})
                |> put_request_guardrail_meta(
                  request_id,
                  meta
                  |> Map.put(:output_applied?, true)
                  |> Map.put(:interrupt, interrupt)
                  |> Map.put(:interrupt_guardrail, label)
                )

              Moto.Hooks.notify_interrupt(agent, request_id, interrupt)
              {:ok, agent, directives}
          end
        end

      _ ->
        {:ok, agent, directives}
    end
  end

  defp run_output_guardrails(agent, _request_id, directives), do: {:ok, agent, directives}

  defp force_request_failure(agent, request_id, error) do
    state =
      update_in(agent.state, [:requests, request_id], fn
        nil ->
          %{status: :failed, error: error, completed_at: System.system_time(:millisecond)}

        req ->
          req
          |> Map.put(:status, :failed)
          |> Map.put(:error, error)
          |> Map.put(:completed_at, System.system_time(:millisecond))
          |> Map.delete(:result)
      end)

    %{agent | state: Map.put(state, :completed, true)}
  end

  defp current_outcome(agent, request_id) do
    case Request.get_result(agent, request_id) do
      {:ok, result} -> {:ok, result}
      {:error, error} -> {:error, error}
      _ -> nil
    end
  end

  defp signal_request_id(%{data: %{metadata: metadata}}) when is_map(metadata) do
    Map.get(metadata, :request_id) || Map.get(metadata, "request_id")
  end

  defp signal_request_id(_signal), do: nil

  defp tool_call_name(%{name: name}) when is_binary(name), do: name
  defp tool_call_name(%{"name" => name}) when is_binary(name), do: name
  defp tool_call_name(_tool_call), do: "unknown_tool"

  defp tool_call_id(%{id: id}) when is_binary(id), do: id
  defp tool_call_id(%{"id" => id}) when is_binary(id), do: id
  defp tool_call_id(_tool_call), do: nil

  defp tool_call_arguments(%{arguments: arguments}) when is_map(arguments), do: arguments
  defp tool_call_arguments(%{"arguments" => arguments}) when is_map(arguments), do: arguments
  defp tool_call_arguments(_tool_call), do: %{}

  defp normalize_interrupt(%Interrupt{} = interrupt), do: interrupt
  defp normalize_interrupt(interrupt), do: Interrupt.new(interrupt)
end
