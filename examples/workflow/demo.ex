defmodule Bagu.Examples.Workflow.Demo do
  @moduledoc false

  alias Bagu.Demo.CLI

  @spec main([String.t()]) :: :ok
  def main(argv) do
    CLI.run_command(argv, "workflow", fn -> :ok end, &run/2)
  end

  @spec usage() :: :ok
  def usage, do: CLI.usage("workflow")

  defp run(options, log_level) do
    print_header(log_level)
    CLI.print_log_status(log_level)

    if options.dry_run? do
      IO.puts("Dry run: workflow not executed.")
    else
      value = parse_value!(options.prompt || "5")

      case workflow_module().run(%{value: value}, return: :debug) do
        {:ok, debug} ->
          IO.puts("workflow> input=#{value} output=#{inspect(debug.output)}")
          IO.puts("workflow> steps=#{inspect(debug.steps)}")

        {:error, reason} ->
          IO.puts("error> #{Bagu.format_error(reason)}")
      end
    end

    :ok
  end

  defp print_header(log_level) do
    {:ok, inspection} = Bagu.inspect_workflow(workflow_module())

    IO.puts("Bagu workflow demo")
    IO.puts("Workflow: #{inspection.id}")
    IO.puts("Steps: #{Enum.map_join(inspection.steps, ", ", &Atom.to_string(&1.name))}")

    if log_level == :trace do
      IO.puts("Dependencies: #{inspect(inspection.dependencies)}")
      IO.puts("Output: #{inspect(inspection.output)}")
    end

    IO.puts("")
  end

  defp parse_value!(value) do
    value
    |> String.trim()
    |> Integer.parse()
    |> case do
      {integer, ""} ->
        integer

      _other ->
        raise Mix.Error, message: "workflow demo expects an integer input, got: #{inspect(value)}"
    end
  end

  defp workflow_module do
    Module.concat([Bagu, Examples, Workflow, Workflows, MathPipeline])
  end
end
