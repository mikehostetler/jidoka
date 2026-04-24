# Tools And Capabilities

Capabilities are the model-visible or model-reachable things an agent can use.
They live in `capabilities do`.

```elixir
capabilities do
  tool MyApp.Tools.LookupOrder
  ash_resource MyApp.Accounts.User
  mcp_tools endpoint: :github, prefix: "github_"
  skill "support-discipline"
  load_path "../skills"
  plugin MyApp.Plugins.Support
  subagent MyApp.BillingSpecialist
  workflow MyApp.Workflows.RefundReview
  handoff MyApp.BillingSpecialist, as: :transfer_billing_ownership
end
```

Bagu validates that published capability names do not conflict.

## Direct Tools

Use `Bagu.Tool` for deterministic application functions:

```elixir
defmodule MyApp.Tools.AddNumbers do
  use Bagu.Tool,
    description: "Adds two integers together.",
    schema: Zoi.object(%{a: Zoi.integer(), b: Zoi.integer()}),
    output_schema: Zoi.object(%{sum: Zoi.integer()})

  @impl true
  def run(%{a: a, b: b}, _context) do
    {:ok, %{sum: a + b}}
  end
end
```

Attach it:

```elixir
capabilities do
  tool MyApp.Tools.AddNumbers
end
```

Bagu tools are Zoi-only for `schema` and `output_schema`. They compile to plain
Jido action modules underneath.

## Ash Resources

Use `ash_resource` to expose generated `AshJido` actions:

```elixir
capabilities do
  ash_resource MyApp.Accounts.User
end
```

For Ash resource tools, Bagu:

- expands the resource into generated action modules
- injects the resource domain into runtime context
- requires `context.actor` for chat turns using those tools

```elixir
MyApp.UserAgent.chat(pid, "List users.", context: %{actor: current_user})
```

## MCP Tools

Use `mcp_tools` when tools live behind an MCP endpoint:

```elixir
capabilities do
  mcp_tools endpoint: :github, prefix: "github_"
end
```

Endpoints can come from config, runtime registration, or inline compiled-agent
configuration. Imported specs reference endpoint names only; executable MCP
transport configuration stays in application code or config.

## Skills

Skills are prompt-level capability bundles built on Jido.AI skills:

```elixir
capabilities do
  skill "math-discipline"
  load_path "../skills"
end
```

Bagu uses skills to:

- render skill prompt text into effective instructions
- narrow visible tools when the skill declares `allowed-tools`
- merge action-backed skill tools when the skill defines actions

## Plugins

Plugins package reusable tool sets:

```elixir
defmodule MyApp.Plugins.Math do
  use Bagu.Plugin,
    description: "Provides extra math tools.",
    tools: [MyApp.Tools.MultiplyNumbers]
end
```

Attach the plugin:

```elixir
capabilities do
  plugin MyApp.Plugins.Math
end
```

Plugin-provided tools are merged into the same tool registry as direct tools.

## Subagents

Use `subagent` when the parent should delegate one task to another agent and
then continue owning the turn:

```elixir
capabilities do
  subagent MyApp.ResearchAgent,
    as: :research_agent,
    description: "Ask the research specialist for concise notes.",
    target: :ephemeral,
    timeout: 30_000,
    forward_context: {:only, [:tenant, :session]},
    result: :structured
end
```

Subagents are agent-as-tool. They are not ownership transfer and they are not
workflow graphs.

## Workflow Capabilities

Use `workflow` when the agent should choose a deterministic process:

```elixir
capabilities do
  workflow MyApp.Workflows.RefundReview,
    as: :review_refund,
    description: "Review refund eligibility for a known account and order.",
    timeout: 30_000,
    forward_context: {:only, [:tenant, :session]},
    result: :structured
end
```

The generated tool schema is the workflow input schema. Runtime execution goes
through `Bagu.Workflow.run/3`. The model sees a bounded result such as
`%{output: output}` or structured metadata when `result: :structured`.

## Handoffs

Use `handoff` when another agent should own future turns for the same
conversation:

```elixir
capabilities do
  handoff MyApp.BillingAgent,
    as: :transfer_billing_ownership,
    description: "Transfer ongoing billing ownership to billing.",
    target: :auto,
    forward_context: {:only, [:tenant, :session, :account_id]}
end
```

The handoff tool accepts:

- `message`, required
- `summary`, optional
- `reason`, optional

On success, `Bagu.chat/3` returns `{:handoff, %Bagu.Handoff{}}` and records the
conversation owner.

## Name Conflicts

Bagu rejects duplicate published names across:

- direct tools
- Ash-generated tools
- MCP tools
- skill tools
- plugin tools
- subagents
- workflows
- handoffs

When a conflict appears, rename the capability with `as:` where supported or
change the published tool name.
