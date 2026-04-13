defmodule Jidoka.HardeningEvaluationTest do
  use ExUnit.Case, async: false

  alias Jidoka.Hardening.EvaluationFixtures
  alias Jidoka.Hardening.EvaluationHarness

  @fixtures EvaluationFixtures.load!()

  test "fixture corpus includes pass, retryable, and resume scenarios" do
    fixture_ids = Enum.map(@fixtures, & &1.id)

    assert "passing_task" in fixture_ids
    assert "retryable_verifier_failure" in fixture_ids
    assert "resume_oriented" in fixture_ids
    assert length(@fixtures) >= 3
  end

  test "fixtures classify against expected outcome and attempt counts" do
    for fixture <- @fixtures do
      assert {:ok, result} = EvaluationHarness.run_fixture(fixture)

      initial = Enum.at(result.steps, 0).before
      final = result.final

      expected = fixture.expected

      assert initial.run_status == expected.initial_run_status
      assert initial.run_outcome == expected.initial_outcome
      assert initial.latest_verification_status == expected.initial_verification_status
      assert final.run_status == expected.final_run_status
      assert final.run_outcome == expected.final_outcome
      assert final.attempt_count == expected.final_attempt_count
      assert final.latest_verification_status == expected.final_verification_status
      assert length(final.artifact_summaries) == expected.artifact_count

      if fixture.id == "resume_oriented" do
        assert length(result.steps) == 2
        assert Enum.at(result.steps, 0).action == :resume
        assert Enum.at(result.steps, 0).after.run_status == expected.resume_status
      end

      if fixture.id == "retryable_verifier_failure" do
        assert Enum.at(result.steps, 0).action == :retry
        assert Enum.at(result.steps, 1).action == :approve
        assert Enum.at(result.steps, 0).before.run_status == :failed
      end
    end
  end
end
