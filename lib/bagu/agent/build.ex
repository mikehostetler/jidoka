defmodule Bagu.Agent.Build do
  @moduledoc false

  @spec before_compile(Macro.Env.t()) :: Macro.t()
  def before_compile(%Macro.Env{} = env) do
    env
    |> Bagu.Agent.Definition.build!()
    |> Bagu.Agent.Codegen.emit()
  end
end
