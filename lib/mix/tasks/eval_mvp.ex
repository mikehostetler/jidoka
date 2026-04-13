defmodule Mix.Tasks.EvalMvp do
  use Mix.Task

  alias Jidoka.Hardening.EvaluationFixtures
  alias Jidoka.Hardening.EvaluationHarness

  @shortdoc "Run the MVP end-to-end fixture corpus through public runtime APIs."

  @moduledoc """
  Run the hardening evaluation fixtures.

  Example:

      mix eval_mvp
  """

  @impl true
  def run(_args) do
    Mix.Task.run("app.start")

    results =
      EvaluationFixtures.load!()
      |> Enum.map(&EvaluationHarness.run_fixture/1)

    Enum.each(results, &print_result/1)

    if Enum.any?(results, &match?({:error, _}, &1)) do
      Mix.raise("one or more evaluation scenarios failed")
    else
      results_match_expectations?(results)

      if Enum.any?(results, fn
           {:ok, result} -> result.final.run_status != :completed
           {:error, _} -> false
         end) do
        Mix.raise("one or more scenarios did not finish as expected")
      end
    end
  end

  defp results_match_expectations?(results) do
    Enum.each(results, fn
      {:ok, result} ->
        validate_result(result)

      {:error, _} ->
        :ok
    end)
  end

  defp validate_result(result) do
    expected = result.expected
    initial = Enum.at(result.steps, 0).before
    final = result.final

    if initial.run_status != expected.initial_run_status ||
         initial.latest_verification_status != expected.initial_verification_status ||
         final.run_status != expected.final_run_status ||
         final.run_outcome != expected.final_outcome ||
         final.attempt_count != expected.final_attempt_count ||
         final.latest_verification_status != expected.final_verification_status ||
         length(final.artifact_summaries) != expected.artifact_count do
      Mix.raise("fixture #{result.fixture_id} failed expected classification")
    end

    :ok
  end

  defp print_result({:ok, result}) do
    final = result.final

    step_lines =
      result.steps
      |> Enum.map(fn step -> "  #{inspect(step.action)}" end)
      |> Enum.join(",")

    IO.puts(
      [
        "scenario=#{result.fixture_id}",
        "status=#{final.run_status}",
        "outcome=#{inspect(final.run_outcome)}",
        "attempts=#{final.attempt_count}",
        "verification=#{inspect(final.latest_verification_status)}",
        "artifact_refs=#{inspect(final.artifact_refs)}",
        "artifacts=#{length(final.artifact_summaries)}",
        "steps=#{step_lines}"
      ]
      |> Enum.join(" | ")
    )
  end

  defp print_result({:error, {fixture, reason}}) do
    IO.puts("scenario=#{fixture.id} failed=#{inspect(reason)}")
  end

  defp print_result({:error, reason}) do
    IO.puts("scenario error=#{inspect(reason)}")
  end
end
