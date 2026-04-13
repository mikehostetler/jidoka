defmodule Jidoka.Hardening.EvaluationHarness do
  @moduledoc "End-to-end evaluator that drives MVP runtime through public APIs only."

  alias Jidoka

  @poll_interval 20
  @poll_attempts 250

  def run_all_fixtures do
    Jidoka.Hardening.EvaluationFixtures.load!()
    |> Enum.map(&run_fixture/1)
  end

  def run_fixture(fixture) when is_map(fixture) do
    session_id = fixture_session_id(fixture)
    workspace = fixture_workspace_path(fixture)

    with :ok <- File.mkdir_p(workspace),
         {:ok, session_ref} <-
           Jidoka.start_session(id: session_id, cwd: workspace),
         {:ok, %{run: run}} <-
           Jidoka.submit(
             session_ref,
             fixture.task,
             execution_adapter: fixture.execution_adapter,
             verification_adapter: fixture.verification_adapter
           ),
         {:ok, final_context, step_results} <-
           execute_steps(%{session_ref: session_ref, run_id: run.id}, fixture.steps),
         {:ok, summary} <- summarize_run(final_context) do
      :ok = maybe_close(final_context.session_ref)

      {:ok,
       %{
         fixture_id: fixture.id,
         description: fixture.description,
         final: summary,
         steps: step_results,
         session_ref: final_context.session_ref,
         run_id: run.id,
         expected: fixture.expected
       }}
    else
      error ->
        :ok = maybe_close(session_id)
        error
    end
  end

  defp execute_steps(context, steps) do
    reduced =
      Enum.reduce_while(steps, {:ok, context, []}, fn step,
                                                      {:ok, current_context, step_results} ->
        case execute_step(current_context, step) do
          {:ok, new_context, step_result} ->
            {:cont, {:ok, new_context, [step_result | step_results]}}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
      end)

    case reduced do
      {:ok, final_context, step_results} ->
        {:ok, final_context, Enum.reverse(step_results)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp execute_step(context, :approve) do
    with {:ok, before} <- await_status(context, :awaiting_approval),
         :ok <- Jidoka.approve(context.session_ref, context.run_id),
         {:ok, after_status} <- await_status(context, :completed) do
      {:ok, context, %{action: :approve, before: before, after: after_status}}
    end
  end

  defp execute_step(context, :resume) do
    with {:ok, before} <- await_status(context, :awaiting_approval),
         :ok <- Jidoka.close_session(context.session_ref),
         {:ok, _resumed_session} <- Jidoka.resume_session(context.session_ref),
         {:ok, after_status} <- await_status(context, :awaiting_approval) do
      {:ok, context, %{action: :resume, before: before, after: after_status}}
    end
  end

  defp execute_step(context, {:retry, opts}) when is_map(opts) do
    retry_opts =
      opts
      |> Enum.into([])
      |> Keyword.put_new(:execution_adapter, Jidoka.AttemptExecution.NoopAdapter)

    with {:ok, before} <- await_status(context, :failed),
         :ok <- Jidoka.retry(context.session_ref, context.run_id, retry_opts),
         {:ok, after_status} <- await_status(context, :awaiting_approval) do
      {:ok, context, %{action: :retry, before: before, after: after_status}}
    end
  end

  defp execute_step(_context, _step), do: {:error, :unsupported_step}

  defp summarize_run(context) do
    case Jidoka.run_snapshot(context.session_ref, context.run_id) do
      {:ok, snapshot} ->
        {:ok, run_snapshot_summary(context.session_ref, snapshot)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_snapshot_summary(_session_ref, snapshot) do
    run = snapshot.run
    latest_attempt = Enum.find(snapshot.attempts, &(&1.id == run.latest_attempt_id))

    latest_verification =
      if latest_attempt && latest_attempt.verification_result_id do
        Enum.find(
          snapshot.verification_results,
          &(&1.id == latest_attempt.verification_result_id)
        )
      end

    artifacts =
      Enum.map(snapshot.artifacts, fn artifact ->
        %{id: artifact.id, type: artifact.type, location: artifact.location}
      end)

    %{
      run_id: run.id,
      run_status: run.status,
      run_outcome: run.outcome,
      attempt_count: length(snapshot.attempts),
      latest_attempt_status: latest_attempt && latest_attempt.status,
      latest_attempt_id: latest_attempt && latest_attempt.id,
      latest_attempt_number: latest_attempt && latest_attempt.attempt_number,
      latest_verification_status: latest_verification && latest_verification.status,
      latest_verification_summary: latest_verification && latest_verification.outcome_summary,
      artifact_refs: run.artifact_ids,
      artifact_summaries: artifacts,
      attempts: snapshot.attempts,
      verification_results: snapshot.verification_results
    }
  end

  defp await_status(context, expected_status) do
    await_status(context, expected_status, @poll_attempts)
  end

  defp await_status(_context, _expected, 0), do: {:error, :timeout}

  defp await_status(context, expected, remaining) do
    case Jidoka.run_snapshot(context.session_ref, context.run_id) do
      {:ok, snapshot} ->
        summary = run_snapshot_summary(context.session_ref, snapshot)

        if summary.run_status == expected do
          {:ok, summary}
        else
          Process.sleep(@poll_interval)
          await_status(context, expected, remaining - 1)
        end

      {:error, _reason} ->
        Process.sleep(@poll_interval)
        await_status(context, expected, remaining - 1)
    end
  end

  defp fixture_session_id(fixture) do
    "mvp-eval-" <>
      sanitize(fixture.id) <>
      "-" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end

  defp fixture_workspace_path(fixture) do
    Path.join(System.tmp_dir!(), "jidoka-mvp-eval/#{sanitize(fixture.id)}")
  end

  defp sanitize(nil), do: "fixture"
  defp sanitize(value) when is_atom(value), do: sanitize(Atom.to_string(value))

  defp sanitize(value) when is_binary(value) do
    value
    |> String.replace(~r/[^a-zA-Z0-9_-]/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
  end

  defp maybe_close(session_ref) do
    case Jidoka.close_session(session_ref) do
      :ok -> :ok
      {:error, :not_found} -> :ok
      _error -> :ok
    end
  end
end
