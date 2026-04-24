# Context And Schema

Jidoka uses `context:` for request-scoped application data. Context is available
to hooks, dynamic instructions, tools, Ash resources, memory namespaces,
subagents, workflows, and handoffs.

Context is not automatically injected into model-visible prompt text. Project it
explicitly through instructions, hooks, tools, or memory when the model should
see it.

## Define Context Schema

Compiled agents can define a Zoi map/object schema inside `agent do`:

```elixir
defmodule MyApp.BillingAgent do
  use Jidoka.Agent

  agent do
    id :billing_agent

    schema Zoi.object(%{
      account_id: Zoi.string(),
      tenant: Zoi.string() |> Zoi.default("demo"),
      channel: Zoi.string() |> Zoi.default("support_chat")
    })
  end

  defaults do
    model :fast
    instructions "You help with billing questions."
  end
end
```

The schema is compiled with the agent. Jidoka validates it at compile time and
uses it at runtime before the LLM call starts.

## Defaults With Required Fields

Required fields do not prevent defaulted fields from being exposed:

```elixir
MyApp.BillingAgent.context()
#=> %{tenant: "demo", channel: "support_chat"}
```

If `account_id` is missing at runtime, Jidoka returns a validation error:

```elixir
{:error, reason} = MyApp.BillingAgent.chat(pid, "Show my invoice.")
Jidoka.format_error(reason)
#=> "Invalid context:\n- account_id: is required"
```

Pass required values with `context:`:

```elixir
{:ok, reply} =
  MyApp.BillingAgent.chat(pid, "Show my invoice.",
    context: %{account_id: "acct_123"}
  )
```

## Per-Turn Context

Per-turn context is parsed through the schema:

```elixir
MyApp.BillingAgent.chat(pid, "Help with this invoice.",
  context: %{
    account_id: "acct_123",
    tenant: "acme"
  }
)
```

For compiled agents with a schema, runtime context is parsed by Zoi and merged
with schema defaults. For imported agents, `agent.context` is a plain default
map and per-turn `context:` merges over it.

## Invalid Context Type

`context:` must be a map or keyword list:

```elixir
{:error, reason} = Jidoka.chat(pid, "Hello", context: "acct_123")
Jidoka.format_error(reason)
#=> "Invalid context: pass `context:` as a map or keyword list."
```

Do not pass `tool_context:` to public APIs. That key is internal runtime
plumbing:

```elixir
{:error, reason} = Jidoka.chat(pid, "Hello", tool_context: %{account_id: "acct_123"})
Jidoka.format_error(reason)
#=> "Invalid option: use `context:` for request-scoped data; `tool_context:` is internal."
```

## Dynamic Instructions

Dynamic instructions receive parsed context:

```elixir
defmodule MyApp.SupportPrompt do
  @behaviour Jidoka.Agent.SystemPrompt

  @impl true
  def resolve_system_prompt(%{context: context}) do
    account_id = Map.get(context, :account_id, "unknown")
    "You help the support team with account #{account_id}."
  end
end
```

This is the most direct way to make selected context visible to the model.

## Context In Tools

Tools receive parsed context as the second argument:

```elixir
defmodule MyApp.Tools.ShowTenant do
  use Jidoka.Tool,
    description: "Returns the current tenant.",
    schema: Zoi.object(%{})

  @impl true
  def run(_params, context) do
    {:ok, %{tenant: Map.fetch!(context, :tenant)}}
  end
end
```

Use this for application state the model should not directly control, such as
the current actor, tenant, request id, or permission scope.

## Context Forwarding

Subagents, workflow capabilities, and handoffs support `forward_context`:

```elixir
capabilities do
  subagent MyApp.BillingSpecialist,
    forward_context: {:only, [:tenant, :account_id]}

  workflow MyApp.Workflows.RefundReview,
    forward_context: {:only, [:tenant, :session]}

  handoff MyApp.BillingSpecialist,
    as: :transfer_billing_ownership,
    forward_context: {:except, [:internal_notes]}
end
```

Supported modes:

- `:public`
- `:none`
- `{:only, keys}`
- `{:except, keys}`

Jidoka strips internal runtime keys before forwarding context.

## Context For Memory Namespaces

Memory can use a context key as its namespace:

```elixir
lifecycle do
  memory do
    mode :conversation
    namespace {:context, :session}
    capture :conversation
    retrieve limit: 5
    inject :instructions
  end
end
```

When an agent has a compiled schema, Jidoka validates that the namespace key is
declared in the schema. This catches memory partitioning mistakes at compile
time.
