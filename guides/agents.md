# Agents

Agents are the center of Bagu's public API. A Bagu agent is a compiled Elixir
module that generates a Jido.AI runtime with a smaller, validated authoring
surface.

## DSL Shape

The beta DSL has four sections:

```elixir
defmodule MyApp.SupportAgent do
  use Bagu.Agent

  agent do
    id :support_agent
    description "Front-door customer support agent."

    schema Zoi.object(%{
      tenant: Zoi.string() |> Zoi.default("demo"),
      account_id: Zoi.string() |> Zoi.optional()
    })
  end

  defaults do
    model :fast
    instructions "You help customers with support questions."
  end

  capabilities do
    tool MyApp.Tools.LookupOrder
  end

  lifecycle do
    input_guardrail MyApp.Guardrails.SafePrompt
  end
end
```

`agent do` contains stable identity and compile-time context schema:

- `id` is required and must be lower snake case.
- `description` is optional.
- `schema` is an optional compiled Zoi map/object schema for runtime context.

`defaults do` contains runtime defaults:

- `instructions` is required.
- `model` is optional and defaults to `:fast`.
- `character` is optional structured persona data.

`capabilities do` contains model-visible or model-reachable features:

- `tool`
- `ash_resource`
- `mcp_tools`
- `skill`
- `load_path`
- `plugin`
- `subagent`
- `workflow`
- `handoff`

`lifecycle do` contains non-capability runtime policy:

- `memory`
- `before_turn`
- `after_turn`
- `on_interrupt`
- `input_guardrail`
- `output_guardrail`
- `tool_guardrail`

## Instructions

`defaults.instructions` is what Bagu maps to the underlying Jido.AI system
prompt machinery.

Static string:

```elixir
defaults do
  instructions "You are concise and direct."
end
```

Module resolver:

```elixir
defmodule MyApp.SupportPrompt do
  @behaviour Bagu.Agent.SystemPrompt

  @impl true
  def resolve_system_prompt(%{context: context}) do
    tenant = Map.get(context, :tenant, "unknown")
    "You help support users for tenant #{tenant}."
  end
end

defaults do
  instructions MyApp.SupportPrompt
end
```

MFA resolver:

```elixir
defaults do
  instructions {MyApp.SupportPrompts, :build, ["Support tenant"]}
end
```

Dynamic instructions resolve once per turn using the current runtime context.

## Models

`defaults.model` accepts Bagu/Jido.AI model inputs:

- alias atoms such as `:fast`
- direct strings such as `"anthropic:claude-haiku-4-5"`
- inline maps such as `%{provider: :anthropic, id: "claude-haiku-4-5"}`
- `%LLMDB.Model{}` structs

Use aliases for application defaults and direct strings when an agent needs an
explicit provider/model pair.

## Generated Functions

Compiled agents expose stable beta helpers:

```elixir
MyApp.SupportAgent.start_link(id: "support-1")
MyApp.SupportAgent.chat(pid, "Hello")
MyApp.SupportAgent.id()
MyApp.SupportAgent.name()
MyApp.SupportAgent.instructions()
MyApp.SupportAgent.configured_model()
MyApp.SupportAgent.model()
MyApp.SupportAgent.context_schema()
MyApp.SupportAgent.context()
MyApp.SupportAgent.tools()
MyApp.SupportAgent.tool_names()
MyApp.SupportAgent.subagents()
MyApp.SupportAgent.workflow_names()
MyApp.SupportAgent.handoff_names()
MyApp.SupportAgent.hooks()
MyApp.SupportAgent.guardrails()
```

Prefer public helpers and `Bagu.inspect_agent/1` over internal generated data
functions.

## Chat Turn Lifecycle

A typical `Bagu.chat/3` call does this:

1. Validate public options, including `context:` and `conversation:`.
2. Route to the current handoff owner when a `conversation:` has one.
3. Resolve the target agent server.
4. Parse and merge runtime context.
5. Apply runtime character, hooks, guardrails, memory, MCP sync, and generated
   tool context.
6. Send the request through Jido.AI.
7. Normalize interruptions, handoffs, and errors into public Bagu return shapes.

The model sees only what instructions, memory, skills, and tools expose. Raw
runtime `context:` is application data, not automatically prompt-visible text.

## Compile-Time Feedback

Bagu intentionally rejects legacy or ambiguous placements. Examples:

- `agent.model` must move to `defaults.model`.
- `agent.system_prompt` must be renamed to `defaults.instructions`.
- top-level `tools`, `skills`, `plugins`, `subagents`, `hooks`, `guardrails`,
  and `memory` must move into `capabilities` or `lifecycle`.
- capability names must be unique across direct tools, Ash-generated tools, MCP
  tools, skill tools, plugin tools, subagents, workflows, and handoffs.

Use these errors as structure feedback. The DSL is strict so production agents
are easier to inspect and import/export later.
