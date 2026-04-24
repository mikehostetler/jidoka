defmodule Jidoka.Workflow.Capability.Tool do
  @moduledoc false

  @output_schema Zoi.object(%{output: Zoi.any()})
  @structured_output_schema Zoi.object(%{output: Zoi.any(), workflow: Zoi.map()})

  @doc false
  @spec output_schema(Jidoka.Workflow.Capability.t()) :: Zoi.schema()
  def output_schema(%Jidoka.Workflow.Capability{result: :structured}), do: @structured_output_schema
  def output_schema(%Jidoka.Workflow.Capability{}), do: @output_schema

  @doc false
  @spec tool_module(base_module :: module(), Jidoka.Workflow.Capability.t(), non_neg_integer()) :: module()
  def tool_module(base_module, %Jidoka.Workflow.Capability{} = workflow, index) do
    suffix =
      workflow.name
      |> String.replace(~r/[^A-Za-z0-9_]/, "_")
      |> Macro.camelize()

    Module.concat(base_module, :"WorkflowTool#{suffix}#{index}")
  end

  @doc false
  @spec tool_module_ast(module(), Jidoka.Workflow.Capability.t()) :: Macro.t()
  def tool_module_ast(tool_module, %Jidoka.Workflow.Capability{} = workflow) do
    quote location: :keep do
      defmodule unquote(tool_module) do
        use Jidoka.Tool,
          name: unquote(workflow.name),
          description: unquote(workflow.description),
          schema: unquote(Macro.escape(Jidoka.Workflow.Capability.input_schema(workflow))),
          output_schema: unquote(Macro.escape(Jidoka.Workflow.Capability.output_schema(workflow)))

        @workflow unquote(Macro.escape(workflow))

        @impl true
        def run(params, context) do
          Jidoka.Workflow.Capability.run_workflow_tool(@workflow, params, context)
        end
      end
    end
  end
end
