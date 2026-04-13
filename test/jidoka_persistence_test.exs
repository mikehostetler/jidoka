defmodule JidokaPersistenceTest do
  use ExUnit.Case, async: true

  alias Jidoka.Attempt
  alias Jidoka.Artifact
  alias Jidoka.EnvironmentLease
  alias Jidoka.Event
  alias Jidoka.Outcome
  alias Jidoka.Persistence
  alias Jidoka.Persistence.InMemory
  alias Jidoka.Run
  alias Jidoka.Session
  alias Jidoka.VerificationResult

  describe "durable persistence boundary" do
    test "in-memory adapter round-trips session envelope state without process references" do
      {:ok, session} =
        Session.new(
          id: "session-001",
          workspace_path: "/tmp/repo",
          status: :active,
          run_ids: ["run-001", "run-002"],
          active_run_id: "run-002"
        )

      {:ok, run_a} =
        Run.new(id: "run-001", session_id: session.id, task: "first run", status: :running)

      {:ok, run_b} =
        Run.new(id: "run-002", session_id: session.id, task: "second run", status: :queued)

      {:ok, attempt_a} =
        Attempt.new(
          id: "attempt-a",
          run_id: run_a.id,
          attempt_number: 1,
          status: :running,
          artifact_ids: ["artifact-a"]
        )

      {:ok, attempt_b} =
        Attempt.new(
          id: "attempt-b",
          run_id: run_b.id,
          attempt_number: 1,
          status: :pending
        )

      {:ok, lease} =
        EnvironmentLease.new(
          id: "lease-1",
          attempt_id: attempt_b.id,
          status: :active,
          workspace_path: "/tmp/repo-run"
        )

      {:ok, artifact} =
        Artifact.new(
          id: "artifact-a",
          run_id: run_a.id,
          attempt_id: attempt_a.id,
          type: :transcript,
          status: :ready
        )

      {:ok, verification} =
        VerificationResult.new(
          id: "verification-1",
          attempt_id: attempt_b.id,
          status: :passed,
          outcome_summary: %{errors: 0}
        )

      {:ok, outcome} =
        Outcome.new(
          id: "outcome-1",
          run_id: run_a.id,
          attempt_id: attempt_a.id,
          outcome: :pending
        )

      {:ok, event} =
        Event.new(
          id: "event-1",
          session_id: session.id,
          type: :session_opened,
          payload: %{session_id: session.id}
        )

      {:ok, state} =
        InMemory.new()
        |> save!(session)
        |> save!(run_a)
        |> save!(run_b)
        |> save!(attempt_a)
        |> save!(attempt_b)
        |> save!(lease)
        |> save!(artifact)
        |> save!(verification)
        |> save!(outcome)

      {:ok, state, _record} = InMemory.append_event(state, event)

      {:ok, loaded_session} = InMemory.load_session(state, session.id)
      {:ok, loaded_run_a} = InMemory.load_run(state, run_a.id)
      {:ok, loaded_attempt_a} = InMemory.load_attempt(state, attempt_a.id)
      {:ok, loaded_lease} = InMemory.load_environment_lease(state, lease.id)
      {:ok, loaded_artifact} = InMemory.load_artifact(state, artifact.id)
      {:ok, loaded_verification} = InMemory.load_verification_result(state, verification.id)
      {:ok, loaded_outcome} = InMemory.load_outcome(state, outcome.id)

      assert loaded_session == session
      assert loaded_run_a == run_a
      assert loaded_attempt_a == attempt_a
      assert loaded_lease == lease
      assert loaded_artifact == artifact
      assert loaded_verification == verification
      assert loaded_outcome == outcome

      {:ok, envelope} = InMemory.load_session_envelope(state, session.id)
      assert envelope.session == session
      assert envelope.runs == [run_a, run_b]
      assert envelope.attempts == [attempt_a, attempt_b]
      assert envelope.leases == [lease]
      assert envelope.artifacts == [artifact]
      assert envelope.verification_results == [verification]
      assert envelope.outcomes == [outcome]
      assert [%Persistence.EventRecord{sequence: 1, event: ^event}] = envelope.events

      assert no_pid_data?(envelope)
    end

    test "appended events are ordered and stable per session" do
      {:ok, session_a} =
        Session.new(id: "session-a", workspace_path: "/tmp/repo-a", status: :active)

      {:ok, session_b} =
        Session.new(id: "session-b", workspace_path: "/tmp/repo-b", status: :active)

      {:ok, event_a1} =
        Event.new(
          id: "event-a1",
          session_id: "session-a",
          type: :session_opened,
          payload: %{step: 1}
        )

      {:ok, event_a2} =
        Event.new(
          id: "event-a2",
          session_id: "session-a",
          type: :run_submitted,
          payload: %{step: 2}
        )

      {:ok, event_b1} =
        Event.new(
          id: "event-b1",
          session_id: "session-b",
          type: :session_opened,
          payload: %{step: 1}
        )

      {:ok, state} =
        InMemory.new()
        |> save!(session_a)
        |> save!(session_b)

      {:ok, state, record_a1} = InMemory.append_event(state, event_a1)
      {:ok, state, record_a2} = InMemory.append_event(state, event_a2)
      {:ok, state, record_b1} = InMemory.append_event(state, event_b1)

      {:ok, events_a} = InMemory.list_events_for_session(state, session_a.id)
      {:ok, events_b} = InMemory.list_events_for_session(state, session_b.id)

      assert record_a1.sequence == 1
      assert record_a2.sequence == 2
      assert record_b1.sequence == 1

      assert Enum.map(events_a, & &1.sequence) == [1, 2]
      assert Enum.map(events_a, & &1.event.type) == [:session_opened, :run_submitted]
      assert Enum.map(events_b, & &1.sequence) == [1]
    end

    test "resume reconstruction can be derived from persisted entities alone" do
      {:ok, session} = Session.new(id: "session-resume", workspace_path: "/tmp/resume")

      {:ok, run_alpha} =
        Run.new(id: "run-alpha", session_id: session.id, task: "alpha", status: :completed)

      {:ok, run_beta} =
        Run.new(id: "run-beta", session_id: session.id, task: "beta", status: :running)

      {:ok, attempt_alpha} =
        Attempt.new(id: "attempt-alpha", run_id: run_alpha.id, attempt_number: 1)

      {:ok, attempt_beta} =
        Attempt.new(id: "attempt-beta", run_id: run_beta.id, attempt_number: 2)

      {:ok, artifact_alpha} =
        Artifact.new(
          id: "artifact-alpha",
          run_id: run_alpha.id,
          attempt_id: attempt_alpha.id,
          type: :diff
        )

      {:ok, verification_alpha} =
        VerificationResult.new(
          id: "verification-alpha",
          attempt_id: attempt_alpha.id,
          status: :passed
        )

      {:ok, outcome_beta} =
        Outcome.new(
          id: "outcome-beta",
          run_id: run_beta.id,
          attempt_id: attempt_beta.id,
          outcome: :pending
        )

      {:ok, event_alpha} =
        Event.new(id: "event-alpha", session_id: session.id, type: :session_opened)

      {:ok, event_run} =
        Event.new(
          id: "event-run",
          session_id: session.id,
          type: :run_submitted,
          run_id: run_alpha.id
        )

      {:ok, state} =
        InMemory.new()
        |> save!(session)
        |> save!(run_alpha)
        |> save!(run_beta)
        |> save!(attempt_alpha)
        |> save!(attempt_beta)
        |> save!(artifact_alpha)
        |> save!(verification_alpha)
        |> save!(outcome_beta)

      {:ok, state, _record} = InMemory.append_event(state, event_alpha)
      {:ok, state, _record} = InMemory.append_event(state, event_run)

      {:ok, envelope} = InMemory.load_session_envelope(state, session.id)
      attempts_by_run = Enum.into(envelope.attempts, %{}, &{&1.run_id, &1.id})

      assert attempts_by_run["run-alpha"] == attempt_alpha.id
      assert attempts_by_run["run-beta"] == attempt_beta.id
      assert Enum.any?(envelope.artifacts, &(&1.id == artifact_alpha.id))
      assert Enum.any?(envelope.verification_results, &(&1.id == verification_alpha.id))
      assert Enum.any?(envelope.outcomes, &(&1.id == outcome_beta.id))

      reconstructed = %{
        session_id: envelope.session.id,
        run_count: length(envelope.runs),
        attempt_count: length(envelope.attempts),
        event_count: length(envelope.events)
      }

      assert reconstructed == %{
               session_id: "session-resume",
               run_count: 2,
               attempt_count: 2,
               event_count: 2
             }
    end
  end

  defp save!({:ok, %InMemory{} = state}, record), do: save!(state, record)

  defp save!(%InMemory{} = state, %Session{} = session),
    do: InMemory.save_session(state, session)

  defp save!(%InMemory{} = state, %Run{} = run),
    do: InMemory.save_run(state, run)

  defp save!(%InMemory{} = state, %Attempt{} = attempt),
    do: InMemory.save_attempt(state, attempt)

  defp save!(%InMemory{} = state, %EnvironmentLease{} = lease),
    do: InMemory.save_environment_lease(state, lease)

  defp save!(%InMemory{} = state, %Artifact{} = artifact),
    do: InMemory.save_artifact(state, artifact)

  defp save!(%InMemory{} = state, %VerificationResult{} = result),
    do: InMemory.save_verification_result(state, result)

  defp save!(%InMemory{} = state, %Outcome{} = outcome),
    do: InMemory.save_outcome(state, outcome)

  defp no_pid_data?(value) when is_pid(value), do: false
  defp no_pid_data?(value) when is_list(value), do: Enum.all?(value, &no_pid_data?/1)
  defp no_pid_data?(value) when is_struct(value), do: no_pid_data?(Map.from_struct(value))
  defp no_pid_data?(value) when is_map(value), do: Enum.all?(Map.values(value), &no_pid_data?/1)
  defp no_pid_data?(_), do: true
end
