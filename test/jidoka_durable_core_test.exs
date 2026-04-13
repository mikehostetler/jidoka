defmodule JidokaDurableCoreTest do
  use ExUnit.Case, async: true

  alias Jidoka.Attempt
  alias Jidoka.Artifact
  alias Jidoka.EnvironmentLease
  alias Jidoka.Event
  alias Jidoka.Outcome
  alias Jidoka.Run
  alias Jidoka.Session
  alias Jidoka.VerificationResult

  alias Jidoka.Durable.{
    AttemptStatus,
    ArtifactStatus,
    ArtifactType,
    EnvironmentLeaseMode,
    EnvironmentLeaseStatus,
    EventStatus,
    EventType,
    OutcomeStatus,
    RunStatus,
    SessionStatus,
    VerificationResultStatus
  }

  describe "shared lifecycle vocabularies" do
    test "session status values are explicit" do
      assert SessionStatus.values() == [:initializing, :active, :closed]
      assert SessionStatus.valid?(:initializing)
      refute SessionStatus.valid?(:unknown)
    end

    test "run status values are explicit" do
      assert RunStatus.values() == [
               :queued,
               :running,
               :awaiting_approval,
               :completed,
               :failed,
               :canceled
             ]

      assert RunStatus.valid?(:running)
      refute RunStatus.valid?(:stopped)
    end

    test "attempt status values are explicit" do
      assert AttemptStatus.values() == [
               :pending,
               :running,
               :succeeded,
               :retryable_failed,
               :terminal_failed,
               :canceled
             ]
    end

    test "artifact and verification vocabularies are explicit" do
      assert ArtifactType.values() == [
               :diff,
               :transcript,
               :verifier_report,
               :command_log,
               :execution_report,
               :prompt_report
             ]

      assert ArtifactStatus.values() == [:pending, :ready, :archived]
      assert VerificationResultStatus.values() == [:passed, :retryable_failed, :terminal_failed]

      assert OutcomeStatus.values() == [
               :pending,
               :approved,
               :retryable_failed,
               :terminal_failed,
               :canceled
             ]
    end

    test "event and lease vocabularies are explicit" do
      assert EventType.values() == [
               :session_opened,
               :session_closed,
               :run_submitted,
               :run_updated,
               :attempt_started,
               :attempt_progress,
               :attempt_completed,
               :attempt_failed,
               :artifact_emitted,
               :verification_completed
             ]

      assert EventStatus.values() == [:recorded, :replayed]
      assert EnvironmentLeaseMode.values() == [:exclusive]
      assert EnvironmentLeaseStatus.values() == [:active, :released, :expired]
    end
  end

  test "session constructor requires stable identity, timestamps, status, and metadata" do
    assert {:error, :invalid_id} = Session.new(status: :active)

    assert {:ok, session} =
             Session.new(id: "session-001", workspace_path: "/tmp/workspace", run_ids: ["run-1"])

    assert session.id == "session-001"
    assert session.version == 1
    assert %DateTime{} = session.created_at
    assert %DateTime{} = session.updated_at
    assert session.status == :initializing
    assert session.workspace_path == "/tmp/workspace"
    assert session.run_ids == ["run-1"]

    assert {:error, {:invalid_status, _, :bad}} = Session.new(id: "session-001", status: :bad)
  end

  test "run constructor validates required fields and supports optional future-facing fields" do
    assert {:error, :invalid_id} =
             Run.new(status: :queued, session_id: "session-001", task: "edit")

    assert {:error, :invalid_task} = Run.new(id: "run-001", session_id: "session-001")

    assert {:ok, run} =
             Run.new(
               id: "run-001",
               session_id: "session-001",
               task: "Implement feature",
               parent_run_id: "run-000",
               role: :root
             )

    assert run.id == "run-001"
    assert run.session_id == "session-001"
    assert run.status == :queued
    assert run.parent_run_id == "run-000"
    assert run.role == :root
    assert run.task_pack == :coding
  end

  test "event constructor supports optional lineage metadata" do
    assert {:ok, event} =
             Event.new(
               id: "event-001",
               session_id: "session-001",
               type: :run_submitted,
               run_id: "run-001",
               attempt_id: "attempt-001",
               parent_run_id: "run-000",
               role: :coordinator,
               payload: %{status: :ok}
             )

    assert event.parent_run_id == "run-000"
    assert event.role == :coordinator
    assert event.run_id == "run-001"
    assert event.attempt_id == "attempt-001"
  end

  test "attempt constructor validates lifecycle and identifiers" do
    assert {:error, :invalid_id} = Attempt.new(status: :pending, run_id: "run-001")

    assert {:error, :invalid_attempt_number} =
             Attempt.new(id: "attempt-001", run_id: "run-001", attempt_number: 0)

    assert {:ok, attempt} =
             Attempt.new(
               id: "attempt-001",
               run_id: "run-001",
               attempt_number: 2,
               status: :running,
               artifact_ids: ["artifact-1", "artifact-2"]
             )

    assert attempt.id == "attempt-001"
    assert attempt.status == :running
    assert attempt.attempt_number == 2
    assert attempt.artifact_ids == ["artifact-1", "artifact-2"]
  end

  test "artifact constructor enforces artifact status and type" do
    assert {:error, {:invalid_status, _, :invalid}} =
             Artifact.new(id: "artifact-001", run_id: "run-001", type: :diff, status: :invalid)

    assert {:error, {:invalid_artifact_type, _, :invalid}} =
             Artifact.new(id: "artifact-001", run_id: "run-001", type: :invalid)

    assert {:ok, artifact} =
             Artifact.new(
               id: "artifact-001",
               run_id: "run-001",
               status: :ready,
               type: :diff,
               location: "/tmp/artifacts/diff.patch"
             )

    assert artifact.status == :ready
    assert artifact.type == :diff
  end

  test "environment lease constructor enforces ids and explicit mode/status" do
    assert {:error, :invalid_id} = EnvironmentLease.new(id: "lease-001", status: :active)

    assert {:ok, lease} =
             EnvironmentLease.new(
               id: "lease-001",
               attempt_id: "attempt-001",
               status: :active,
               mode: :exclusive,
               workspace_path: "/tmp/lease"
             )

    assert lease.mode == :exclusive
    assert lease.status == :active
    assert lease.workspace_path == "/tmp/lease"
  end

  test "verification result constructor validates vocabulary" do
    assert {:ok, result} =
             VerificationResult.new(
               id: "verification-001",
               attempt_id: "attempt-001",
               status: :passed,
               outcome_summary: %{tests: "all"}
             )

    assert result.id == "verification-001"
    assert result.status == :passed

    assert {:error, {:invalid_status, _, :unknown}} =
             VerificationResult.new(
               id: "verification-002",
               attempt_id: "attempt-001",
               status: :unknown
             )
  end

  test "outcome constructor enforces final outcomes" do
    assert {:ok, outcome} =
             Outcome.new(id: "outcome-001", run_id: "run-001", outcome: :approved, notes: "Great")

    assert outcome.outcome == :approved
    assert outcome.notes == "Great"

    assert {:error, {:invalid_outcome, _, :bad}} =
             Outcome.new(id: "outcome-001", run_id: "run-001", outcome: :bad)
  end

  test "event constructor validates event shape and payload contract" do
    assert {:error, {:invalid_type, _, :bad}} =
             Event.new(id: "event-001", session_id: "session-001", type: :bad)

    assert {:error, :invalid_payload} =
             Event.new(
               id: "event-001",
               session_id: "session-001",
               type: :session_opened,
               payload: :invalid
             )

    assert {:ok, event} =
             Event.new(
               id: "event-001",
               session_id: "session-001",
               type: :run_submitted,
               run_id: "run-001",
               payload: %{ok: true}
             )

    assert event.status == :recorded
    assert event.type == :run_submitted
    assert event.payload == %{ok: true}
  end
end
