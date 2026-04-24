# Bagu Guides

These guides teach Bagu from the smallest useful chat agent through structured
context, deterministic capabilities, orchestration, imports, debugging, evals,
and production concerns.

Bagu is a pre-beta package. The public beta surface is intentionally small:
compiled agents, imported agents, workflows, structured runtime errors, and a
few runtime facade functions. When a guide mentions Jido, Jido.AI, Runic, or
Jido Memory, treat those as implementation notes unless the API is shown through
the `Bagu` namespace.

## Recommended Reading Path

1. [Getting Started](getting-started.html)
   Build and run the smallest useful Bagu agent.

2. [Agents](agents.html)
   Learn the beta DSL shape, generated functions, and chat-turn lifecycle.

3. [Context And Schema](context-and-schema.html)
   Add runtime context, defaults, required fields, and validation.

4. [Tools And Capabilities](tools-and-capabilities.html)
   Expose deterministic work to agents through tools, resources, MCP, plugins,
   skills, subagents, workflows, and handoffs.

5. [Subagents, Workflows, And Handoffs](subagents-workflows-handoffs.html)
   Choose the right orchestration primitive for a task.

6. [Memory](memory.html)
   Configure conversation memory, namespaces, capture, retrieval, and prompt
   injection.

7. [Characters](characters.html)
   Use structured character data to shape identity and voice.

8. [Imported Agents](imported-agents.html)
   Load constrained JSON/YAML agent specs safely at runtime.

9. [Errors And Debugging](errors-and-debugging.html)
   Handle structured Bagu errors and inspect agents, requests, and workflows.

10. [Evals](evals.html)
    Test deterministic behavior and run live LLM evals.

11. [Examples](examples.html)
    Use the included demos as templates.

12. [Phoenix LiveView](phoenix-liveview.html)
    Integrate a Bagu agent with a LiveView while keeping UI messages separate
    from provider-facing LLM context.

13. [Production](production.html)
    Prepare Bagu for supervised application use and beta release constraints.

## The Bagu Mental Model

Bagu is not a second runtime. It is an opinionated harness over Jido and Jido.AI
that narrows the public surface for common LLM-agent applications.

Use Bagu when you want:

- a structured agent DSL with compile-time validation
- runtime context schemas that fail before a model call starts
- deterministic tools and workflows alongside chat agents
- subagents for one-turn specialist delegation
- handoffs for conversation ownership transfer
- JSON/YAML imported agents with explicit allowlists
- structured runtime errors that can be formatted for users

Avoid starting with the most powerful feature. Start with a single agent and add
only the next capability the application actually needs.

## Core Concepts

An agent is a configurable chat runtime. It has stable identity, runtime
defaults, model-visible capabilities, and lifecycle policy.

A tool is deterministic application work exposed to a model as a callable
action. Bagu tools are Zoi-first wrappers around Jido actions.

A subagent is an agent used as a tool. The parent remains in control of the
turn.

A workflow is a deterministic process owned by application code. It has explicit
input, ordered steps, dependencies, and output.

A handoff transfers future turns in a `conversation:` to another agent.

An imported agent is a constrained runtime representation of the same public
agent shape, loaded from JSON or YAML and resolved through explicit registries.

## Beta Surface

The stable beta entrypoints are:

- `Bagu.chat/3`
- `Bagu.start_agent/2`
- `Bagu.stop_agent/1`
- `Bagu.whereis/2`
- `Bagu.list_agents/1`
- `Bagu.model/1`
- `Bagu.format_error/1`
- `Bagu.import_agent/2`
- `Bagu.import_agent_file/2`
- `Bagu.encode_agent/2`
- `Bagu.inspect_agent/1`
- `Bagu.inspect_request/1`
- `Bagu.inspect_workflow/1`
- `Bagu.handoff_owner/1`
- `Bagu.reset_handoff/1`
- `Bagu.Workflow.run/3`

Generated compiled agents also expose stable helpers such as `start_link/1`,
`chat/3`, `id/0`, `tools/0`, and capability name functions. Internal generated
modules and `__bagu__/0` helpers are not the public authoring surface.
