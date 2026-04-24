# Getting Started

This guide builds the smallest useful Bagu agent, starts it, chats with it, and
handles errors correctly.

## Install

Bagu is pre-beta and is not published to Hex yet. Use the Git repository while
the beta surface is stabilizing:

```elixir
def deps do
  [
    {:bagu, git: "https://github.com/mikehostetler/bagu.git", branch: "main"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## Configure A Provider

The examples use Anthropic through ReqLLM/Jido.AI. Set an API key in the shell:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

During local development, Bagu also loads `.env` through `dotenvy` at runtime.
Shell environment variables still win over `.env` values.

Bagu owns model aliases under `config :bagu, :model_aliases`. In this repo,
`:fast` maps to `"anthropic:claude-haiku-4-5"`.

## Define An Agent

Create a module with `use Bagu.Agent`:

```elixir
defmodule MyApp.AssistantAgent do
  use Bagu.Agent

  agent do
    id :assistant_agent
    description "A small general-purpose assistant."
  end

  defaults do
    model :fast
    instructions "You are a concise assistant. Answer directly."
  end
end
```

The required shape is:

- `agent do`: stable identity and optional context schema
- `defaults do`: model and required instructions
- `capabilities do`: tools and orchestration features, when needed
- `lifecycle do`: memory, hooks, and guardrails, when needed

Only `agent.id` and `defaults.instructions` are required for a basic agent.

## Start And Chat

Start the generated runtime under Bagu's shared supervisor:

```elixir
{:ok, pid} = MyApp.AssistantAgent.start_link(id: "assistant-1")
```

Send a message through the generated helper:

```elixir
{:ok, reply} = MyApp.AssistantAgent.chat(pid, "Write one sentence about Elixir.")
```

Or use the top-level facade:

```elixir
{:ok, reply} = Bagu.chat(pid, "Write one sentence about Elixir.")
```

You can also start by runtime module:

```elixir
{:ok, pid} = Bagu.start_agent(MyApp.AssistantAgent.runtime_module(), id: "assistant-2")
```

Use `Bagu.stop_agent/1` when you own the runtime lifecycle manually:

```elixir
:ok = Bagu.stop_agent(pid)
```

## Handle Results

Public chat calls return one of four shapes:

```elixir
case Bagu.chat(pid, "Hello") do
  {:ok, reply} ->
    reply

  {:interrupt, interrupt} ->
    interrupt

  {:handoff, handoff} ->
    handoff

  {:error, reason} ->
    Bagu.format_error(reason)
end
```

Use `Bagu.format_error/1` at user-facing boundaries. Runtime errors are
structured Bagu/Splode errors, but callers should not need to inspect internal
causes for normal display.

## Try The Built-In Demos

From the Bagu package directory:

```bash
mix bagu chat --dry-run
mix bagu imported --dry-run
mix bagu orchestrator --dry-run
mix bagu support --dry-run
mix bagu workflow --dry-run
```

Remove `--dry-run` to start live examples. Live chat examples require provider
credentials.

```bash
mix bagu chat -- "Use one sentence to explain what Bagu is."
```

## Next Step

Read [Agents](agents.html) to understand the DSL sections and generated
functions before adding tools or orchestration.
