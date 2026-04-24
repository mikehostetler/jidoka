defmodule Jidoka.Workflow.StepAction do
  @moduledoc false

  use Jido.Action,
    name: "jidoka_workflow_step",
    description: "Internal Jidoka workflow step adapter.",
    schema:
      Zoi.object(%{
        __jidoka_workflow_definition__: Zoi.any(),
        __jidoka_workflow_step__: Zoi.any(),
        __jidoka_workflow_state__: Zoi.any() |> Zoi.optional(),
        input: Zoi.any() |> Zoi.optional()
      }),
    output_schema:
      Zoi.object(%{
        __jidoka_workflow_state__: Zoi.any()
      })

  @impl true
  def run(params, context) do
    Jidoka.Workflow.Runtime.run_step(params, context)
  end
end
