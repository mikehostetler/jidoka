defmodule BaguTest.InjectTenantHook do
  use Bagu.Hook, name: "inject_tenant"

  @impl true
  def call(%Bagu.Hooks.BeforeTurn{} = input) do
    sequence = Map.get(input.metadata, :sequence, [])

    {:ok,
     %{
       message: "#{input.message} for acme",
       context: %{tenant: "acme"},
       allowed_tools: ["add_numbers"],
       llm_opts: [temperature: 0.1],
       metadata: %{sequence: sequence ++ ["inject_tenant"], touched?: true}
     }}
  end
end

defmodule BaguTest.RestrictRefundsHook do
  use Bagu.Hook, name: "restrict_refunds"

  @impl true
  def call(%Bagu.Hooks.BeforeTurn{} = input) do
    sequence = Map.get(input.metadata, :sequence, [])
    {:ok, %{metadata: %{sequence: sequence ++ ["restrict_refunds"], mode: :refunds}}}
  end
end

defmodule BaguTest.NormalizeReplyHook do
  use Bagu.Hook, name: "normalize_reply"

  @impl true
  def call(%Bagu.Hooks.AfterTurn{outcome: {:ok, result}}) do
    {:ok, {:ok, "normalized:#{result}"}}
  end

  def call(%Bagu.Hooks.AfterTurn{outcome: {:error, reason}}) do
    {:ok, {:error, {:normalized_error, reason}}}
  end
end

defmodule BaguTest.InterruptBeforeHook do
  use Bagu.Hook, name: "approval_gate"

  @impl true
  def call(%Bagu.Hooks.BeforeTurn{} = input) do
    notify_pid = Map.get(input.context, :notify_pid, Map.get(input.context, "notify_pid"))

    {:interrupt,
     %{
       kind: :approval,
       message: "Approval required",
       data: %{notify_pid: notify_pid, from: :before_turn}
     }}
  end
end

defmodule BaguTest.InterruptAfterHook do
  use Bagu.Hook, name: "interrupt_after_turn"

  @impl true
  def call(%Bagu.Hooks.AfterTurn{} = input) do
    notify_pid = Map.get(input.context, :notify_pid, Map.get(input.context, "notify_pid"))

    {:interrupt,
     %{
       kind: :review,
       message: "Review required",
       data: %{notify_pid: notify_pid, from: :after_turn}
     }}
  end
end

defmodule BaguTest.NotifyOpsHook do
  use Bagu.Hook, name: "notify_ops"

  @impl true
  def call(%Bagu.Hooks.InterruptInput{interrupt: interrupt}) do
    if pid = get_in(interrupt.data, [:notify_pid]) do
      send(pid, {:hook_interrupt, interrupt.kind, interrupt.data[:from]})
    end

    :ok
  end
end

defmodule BaguTest.HookCallbacks do
  def before_turn(%Bagu.Hooks.BeforeTurn{} = input, label) do
    sequence = Map.get(input.metadata, :sequence, [])
    {:ok, %{metadata: %{sequence: sequence ++ [label]}}}
  end

  def after_turn(%Bagu.Hooks.AfterTurn{outcome: {:ok, result}}, suffix) do
    {:ok, {:ok, "#{result}#{suffix}"}}
  end

  def after_turn(%Bagu.Hooks.AfterTurn{outcome: {:error, reason}}, suffix) do
    {:ok, {:error, {suffix, reason}}}
  end

  def notify_interrupt(%Bagu.Hooks.InterruptInput{interrupt: interrupt}, label) do
    if pid = get_in(interrupt.data, [:notify_pid]) do
      send(pid, {:hook_interrupt_callback, label, interrupt.kind})
    end

    :ok
  end
end

defmodule BaguTest.SafePromptGuardrail do
  use Bagu.Guardrail, name: "safe_prompt"

  @impl true
  def call(%Bagu.Guardrails.Input{message: message}) do
    if String.contains?(String.downcase(message), "secret") do
      {:error, :unsafe_prompt}
    else
      :ok
    end
  end
end

defmodule BaguTest.SafeReplyGuardrail do
  use Bagu.Guardrail, name: "safe_reply"

  @impl true
  def call(%Bagu.Guardrails.Output{outcome: {:ok, result}}) when is_binary(result) do
    if String.contains?(String.downcase(result), "unsafe") do
      {:error, :unsafe_reply}
    else
      :ok
    end
  end

  def call(%Bagu.Guardrails.Output{}), do: :ok
end

defmodule BaguTest.ApproveLargeMathToolGuardrail do
  use Bagu.Guardrail, name: "approve_large_math_tool"

  @impl true
  def call(%Bagu.Guardrails.Tool{
        tool_name: "add_numbers",
        arguments: arguments,
        context: context
      }) do
    a = Map.get(arguments, :a, Map.get(arguments, "a", 0))
    b = Map.get(arguments, :b, Map.get(arguments, "b", 0))

    if a + b > 40 do
      notify_pid = Map.get(context, :notify_pid, Map.get(context, "notify_pid"))

      {:interrupt,
       %{
         kind: :approval,
         message: "Large calculations require approval",
         data: %{notify_pid: notify_pid, from: :tool_guardrail}
       }}
    else
      :ok
    end
  end

  def call(%Bagu.Guardrails.Tool{}), do: :ok
end

defmodule BaguTest.GuardrailCallbacks do
  def input(%Bagu.Guardrails.Input{} = input, label) do
    sequence = Map.get(input.metadata, :sequence, [])

    if String.contains?(input.message, "blocked_by_#{label}") do
      {:error, {:blocked, label}}
    else
      {:error, {:input_callback, sequence ++ [label]}}
    end
  end

  def output(%Bagu.Guardrails.Output{}, label), do: {:error, {:output_callback, label}}
  def tool(%Bagu.Guardrails.Tool{}, label), do: {:error, {:tool_callback, label}}
end

defmodule BaguTest.HookedAgent do
  use Bagu.Agent

  agent do
    id :hooked_agent
  end

  defaults do
    model :fast
    instructions "You have hooks."
  end

  lifecycle do
    before_turn BaguTest.InjectTenantHook
    before_turn {BaguTest.HookCallbacks, :before_turn, ["dsl_mfa"]}
    after_turn BaguTest.NormalizeReplyHook
    after_turn {BaguTest.HookCallbacks, :after_turn, ["!"]}
    on_interrupt BaguTest.NotifyOpsHook
    on_interrupt {BaguTest.HookCallbacks, :notify_interrupt, ["dsl_mfa"]}
  end
end

defmodule BaguTest.GuardrailedAgent do
  use Bagu.Agent

  agent do
    id :guardrailed_agent
  end

  defaults do
    model :fast
    instructions "You enforce guardrails."
  end

  capabilities do
    tool BaguTest.AddNumbers
  end

  lifecycle do
    on_interrupt BaguTest.NotifyOpsHook

    input_guardrail BaguTest.SafePromptGuardrail
    output_guardrail BaguTest.SafeReplyGuardrail
    tool_guardrail BaguTest.ApproveLargeMathToolGuardrail
  end
end

defmodule BaguTest.InterruptingAgent do
  use Bagu.Agent

  agent do
    id :interrupting_agent
  end

  defaults do
    model :fast
    instructions "You may interrupt."
  end

  lifecycle do
    before_turn BaguTest.InterruptBeforeHook
    on_interrupt BaguTest.NotifyOpsHook
  end
end
