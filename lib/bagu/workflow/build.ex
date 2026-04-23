defmodule Bagu.Workflow.Build do
  @moduledoc false

  @spec before_compile(Macro.Env.t()) :: Macro.t()
  def before_compile(%Macro.Env{} = env) do
    env
    |> Bagu.Workflow.Definition.build!()
    |> Bagu.Workflow.Codegen.emit()
  end
end
