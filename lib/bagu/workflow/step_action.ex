defmodule Bagu.Workflow.StepAction do
  @moduledoc false

  use Jido.Action,
    name: "bagu_workflow_step",
    description: "Internal Bagu workflow step adapter.",
    schema:
      Zoi.object(%{
        __bagu_workflow_definition__: Zoi.any(),
        __bagu_workflow_step__: Zoi.any(),
        __bagu_workflow_state__: Zoi.any() |> Zoi.optional(),
        input: Zoi.any() |> Zoi.optional()
      }),
    output_schema:
      Zoi.object(%{
        __bagu_workflow_state__: Zoi.any()
      })

  @impl true
  def run(params, context) do
    Bagu.Workflow.Runtime.run_step(params, context)
  end
end
