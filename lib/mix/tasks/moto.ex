defmodule Mix.Tasks.Moto do
  use Mix.Task

  @shortdoc "Runs Moto demo REPLs"

  @moduledoc """
  Runs Moto demo agents through a Mix task.

      mix moto chat --dry-run
      mix moto imported -- "Add 17 and 25"
      mix moto chat --log-level debug -- "Add 17 and 25"
      mix moto workflow --dry-run
      mix moto orchestrator --log-level trace -- "Use the research_agent specialist ..."
      mix moto kitchen_sink --log-level trace --dry-run
  """

  @impl true
  def run(argv) do
    case argv do
      [] ->
        usage()

      ["--help"] ->
        usage()

      ["-h"] ->
        usage()

      [demo | rest] ->
        case Moto.Demo.preload(demo) do
          :ok ->
            _ = Mix.Task.run("app.start")

            case Moto.Demo.load(demo) do
              {:ok, module} -> apply(module, :main, [rest])
              {:error, message} -> raise Mix.Error, message: message
            end

          {:error, message} ->
            raise Mix.Error, message: message
        end
    end
  end

  defp usage do
    Mix.shell().info(
      "mix moto <chat|imported|workflow|orchestrator|kitchen_sink> [--log-level info|debug|trace] [--dry-run] [prompt]"
    )
  end
end
