defmodule Jidoka.Verifier do
  @moduledoc """
  Boundary for typed verifier selection and execution.
  """

  defmodule VerifierSpec do
    @moduledoc """
    Typed verifier input passed to an adapter.
    """

    alias Jidoka.EnvironmentLease
    alias Jidoka.AttemptExecution.AttemptOutput

    @enforce_keys [
      :session_id,
      :run_id,
      :attempt_id,
      :task,
      :attempt_number,
      :environment_lease,
      :adapter,
      :execution_output
    ]

    defstruct [
      :session_id,
      :run_id,
      :attempt_id,
      :task,
      :attempt_number,
      :environment_lease,
      :task_pack,
      :metadata,
      :execution_output,
      :adapter
    ]

    @type t :: %__MODULE__{
            session_id: String.t(),
            run_id: String.t(),
            attempt_id: String.t(),
            task: String.t(),
            attempt_number: pos_integer(),
            environment_lease: EnvironmentLease.t(),
            task_pack: atom() | String.t(),
            metadata: map(),
            execution_output: AttemptOutput.t(),
            adapter: module()
          }
  end

  defmodule VerificationOutput do
    @moduledoc """
    Typed result returned by verifier adapters.
    """

    @enforce_keys [:status]
    defstruct [
      :status,
      outcome_summary: %{},
      metadata: %{}
    ]

    @type status :: :passed | :retryable_failed | :terminal_failed

    @type t :: %__MODULE__{
            status: status(),
            outcome_summary: map(),
            metadata: map()
          }
  end

  @callback execute(VerifierSpec.t()) :: {:ok, VerificationOutput.t()} | {:error, term()}

  @doc """
  Execute the typed verifier spec using the configured adapter.
  """
  @spec execute(VerifierSpec.t()) :: {:ok, VerificationOutput.t()} | {:error, term()}
  def execute(%VerifierSpec{adapter: nil} = spec),
    do: execute(%{spec | adapter: __MODULE__.NoopAdapter})

  def execute(%VerifierSpec{} = spec), do: spec.adapter.execute(spec)
end
