defmodule Mix.Tasks.Bagu do
  use Mix.Task

  @shortdoc "Runs Bagu demo REPLs"

  @moduledoc """
  Runs Bagu demo agents through a Mix task.

      mix bagu chat --dry-run
      mix bagu imported -- "Add 17 and 25"
      mix bagu chat --log-level debug -- "Add 17 and 25"
      mix bagu support --dry-run
      mix bagu workflow --dry-run
      mix bagu orchestrator --log-level trace -- "Use the research_agent specialist ..."
      mix bagu kitchen_sink --log-level trace --dry-run
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
        case Bagu.Demo.preload(demo) do
          :ok ->
            _ = Mix.Task.run("app.start")

            case Bagu.Demo.load(demo) do
              {:ok, module} -> apply(module, :main, [rest])
              {:error, message} -> raise Mix.Error, message: message
            end

          {:error, message} ->
            raise Mix.Error, message: message
        end
    end
  end

  defp usage do
    demos =
      Bagu.Demo.names()
      |> Enum.join("|")

    Mix.shell().info("mix bagu <#{demos}> [--log-level info|debug|trace] [--dry-run] [prompt]")
  end
end
