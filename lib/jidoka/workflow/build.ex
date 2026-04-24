defmodule Jidoka.Workflow.Build do
  @moduledoc false

  @spec before_compile(Macro.Env.t()) :: Macro.t()
  def before_compile(%Macro.Env{} = env) do
    env
    |> Jidoka.Workflow.Definition.build!()
    |> Jidoka.Workflow.Codegen.emit()
  end
end
