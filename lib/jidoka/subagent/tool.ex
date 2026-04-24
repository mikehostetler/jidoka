defmodule Jidoka.Subagent.Tool do
  @moduledoc false

  @task_schema Zoi.object(%{task: Zoi.string()})
  @text_output_schema Zoi.object(%{result: Zoi.string()})
  @structured_output_schema Zoi.object(%{result: Zoi.string(), subagent: Zoi.map()})

  @spec task_schema() :: Zoi.schema()
  def task_schema, do: @task_schema

  @spec output_schema(Jidoka.Subagent.t()) :: Zoi.schema()
  def output_schema(%Jidoka.Subagent{result: :structured}), do: @structured_output_schema
  def output_schema(%Jidoka.Subagent{}), do: @text_output_schema

  @spec tool_module(base_module :: module(), Jidoka.Subagent.t(), non_neg_integer()) :: module()
  def tool_module(base_module, %Jidoka.Subagent{} = subagent, index) do
    suffix =
      subagent.name
      |> String.replace(~r/[^A-Za-z0-9_]/, "_")
      |> Macro.camelize()

    Module.concat(base_module, :"SubagentTool#{suffix}#{index}")
  end

  @spec tool_module_ast(module(), Jidoka.Subagent.t()) :: Macro.t()
  def tool_module_ast(tool_module, %Jidoka.Subagent{} = subagent) do
    quote location: :keep do
      defmodule unquote(tool_module) do
        use Jidoka.Tool,
          name: unquote(subagent.name),
          description: unquote(subagent.description),
          schema: unquote(Macro.escape(Jidoka.Subagent.task_schema())),
          output_schema: unquote(Macro.escape(Jidoka.Subagent.output_schema(subagent)))

        @subagent unquote(Macro.escape(subagent))

        @impl true
        def run(params, context) do
          Jidoka.Subagent.run_subagent_tool(@subagent, params, context)
        end
      end
    end
  end
end
