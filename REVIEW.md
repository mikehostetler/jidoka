# Moto Project Review

Date: 2026-04-21

Baseline commit: `9b9db9a test: add live filesystem mcp coverage`

Dependency check: Moto now compiles and passes tests against Hex `jido 2.2.0`
and Hex `jido_ai 2.1.0`. `ash_jido` is sourced from GitHub rather than the
local reference checkout.

## Executive Summary

Moto has crossed from concept spike into a coherent first-pass package. The
current codebase supports the main agent authoring path we set out to prove:
compiled Spark DSL agents, imported JSON/YAML agents, tools, skills, MCP tool
sync, plugins, hooks, guardrails, context, memory, subagents, and inspection.

The most important conclusion is that Moto should not broaden again yet. The
right next phase is runtime polish and hardening around the current surface. The
core concepts are present, but several are still first-pass integrations that
need simpler edges, better failure modes, and clearer docs before the package
should add workflows, handoffs, typed context, artifact delivery, or MCP server
publishing.

## Current Verification

The current baseline is clean and testable.

| Check | Result |
| --- | --- |
| `mix test` | `133 tests, 0 failures` |
| `mix compile --warnings-as-errors` | passing |
| Jido dependency source | Hex `jido 2.2.0` with override |
| Jido.AI dependency source | Hex `jido_ai 2.1.0` with override |
| Ash Jido dependency source | GitHub `agentjido/ash_jido` |
| Live MCP coverage | filesystem MCP server syncs tools into a running Moto agent |

## TODO Alignment

The high-level checklist in `TODO.md` is accurate. Moto has a real first-pass
implementation for every item currently marked as complete.

| TODO Item | Status | Review |
| --- | --- | --- |
| `model` | Implemented | Model aliases and Jido.AI resolution are working. |
| `tools` | Implemented | `Moto.Tool` provides a narrow wrapper over `Jido.Action`. |
| `plugins` | Implemented | Plugins are first-class and can contribute tools. |
| `dynamic system_prompt` | Implemented | String, module, and MFA paths are supported. |
| `hooks` | Implemented | DSL defaults and per-turn overrides are supported. |
| `context` | Implemented | Runtime `context` is the public per-turn data bag. |
| `guardrails` | Implemented | Input, output, and tool guardrails exist with non-mutating semantics. |
| `memory` | Implemented, needs hardening | Conversation-first memory exists, but should remain under runtime polish. |
| `skills` | Implemented | Module and runtime-loaded skill paths are present. |
| MCP tool sync | Implemented, recently hardened | Live filesystem MCP integration now proves real tool sync. |
| imported JSON/YAML agents | Implemented | Main authoring features have constrained import support. |
| `ash_resource` integration | Implemented | Ash resource tools are available with context-based actor handling. |
| `subagents` | Implemented, needs hardening | Manager-pattern subagents exist as tool-like specialists. |
| observability / inspection | Implemented | `inspect_agent`, `inspect_request`, and CLI debug output are useful. |

## What Is Strong

Moto now has a clear public mental model. The package feels like an agent
authoring layer instead of a thin collection of helper functions.

The strongest design choices are:

- `context` is the single public per-turn data bag, and model-visible projection is explicit.
- Hooks and guardrails are separate concepts, which keeps mutation and validation distinct.
- Plugins remain the deeper extension mechanism without forcing users into raw Jido internals.
- Subagents use the manager pattern first, which avoids premature workflow or swarm complexity.
- Imported agents are constrained by explicit registries, which is safer than arbitrary runtime code in JSON/YAML.
- MCP is currently scoped as another tool source, which is the right first MCP layer.
- The debug story is now Moto-shaped instead of raw Jido log spam.

## Current Risks

The main risks are not missing features. They are boundary clarity and runtime reliability.

### Dependency Boundary

Moto now depends on Hex releases for `jido` and `jido_ai`. This is healthier
than the local vendored dependency baseline and should remain the default.

`ash_jido` is sourced from GitHub because there is no Hex package available.
`jido_mcp` and `jido_memory` are also git dependencies. `jido_memory` currently
declares older Jido/Jido.AI constraints (`jido ~> 2.0.0-rc.5` and
`jido_ai == 2.0.0-rc.0`), so Moto still needs direct `jido` and `jido_ai`
overrides to keep the graph on current Hex Jido releases.

### MCP Sync Boundary

Moto owns `Moto.MCP.Sync` as the default sync adapter and exposes `Moto.MCP` as
the public facade for configured, runtime-registered, and inline MCP endpoints.
The adapter remains necessary because real MCP servers commonly publish JSON
Schemas containing metadata such as `$schema`, `$id`, and `format`, while the
lower-level proxy generator rejects those keywords.

This is pragmatic, but it is duplicated responsibility with `jido_mcp`. The
schema compatibility cleanup probably belongs upstream in `jido_mcp` once the
shape is proven.

### Memory Stability

Memory is implemented, but it should remain a hardening target. The concept is
right: conversation-first, opt-in, bounded retrieval, no raw memory tools by
default. The remaining work is around edge cases, namespace behavior, and making
failure modes boring.

### Subagent Runtime Edges

The manager pattern is the correct v1. The next work should harden it rather
than broaden it. The sharp edges to keep reviewing are peer resolution, module
verification, context forwarding, one-hop enforcement, metadata inspection, and
clear failure shapes.

### Feature Surface Density

Moto now has many first-pass concepts. That is acceptable for a spike, but entry
level Elixir developers need strong bumpers. Docs and examples need to keep
showing the simplest path first.

## Recommended Next Work

The next phase should remain `runtime polish`.

1. Reconcile dependency patches.

Keep `jido` and `jido_ai` on Hex releases. Move any required `jido_mcp` and
`jido_memory` compatibility fixes upstream, then reduce Moto-owned shims where
possible.

2. Harden MCP as a client/tool source.

Keep the scope narrow: configured MCP endpoints sync tools into Moto agents.
Add better errors for missing endpoint config, server startup failure, schema
rejection, and partial registration.

3. Harden subagents.

Focus on the manager pattern only. Add tests and docs around context forwarding,
peer lookup failures, nested delegation blocking, child error propagation, and
inspection metadata.

4. Improve observability without adding concepts.

Keep improving `Moto.inspect_agent/1`, `Moto.inspect_request/1`, and `mix moto
--log-level`. Avoid introducing raw telemetry or signal concepts into the public
surface unless there is a very clear developer-facing story.

5. Clarify docs around extension points.

The README should make the boundaries obvious:

| Concept | Purpose |
| --- | --- |
| Tool | Model-callable capability |
| Skill | Prompt/tool bundle used to shape behavior |
| MCP tools | Remote tools synced from configured MCP endpoints |
| Plugin | Deeper extension point and runtime integration |
| Hook | Per-turn mutation or enrichment |
| Guardrail | Non-mutating validation, block, or interrupt |
| Context | Runtime application data, not automatic prompt text |
| Memory | Opt-in conversation recall |
| Subagent | Manager-controlled specialist exposed as a tool |

## Recommended TODO Refinement

The current `TODO.md` is directionally correct. The only refinement I would make
is to split the completed foundation into two buckets: implemented and
implemented-but-hardening. This prevents the checklist from implying that every
feature is production-stable.

Suggested categories:

| Category | Items |
| --- | --- |
| Implemented and stable enough for the spike | model, tools, plugins, dynamic system prompt, context, hooks, guardrails, imports, Ash resources, inspection |
| Implemented but active hardening targets | memory, MCP tool sync, subagents, demo/runtime observability |
| Explicitly later | delivery/artifacts, typed context, tool exposure/gating, handoffs, workflow, resume/persistence |

## Not Recommended Next

These should remain out of scope until the current runtime is more boring:

- Moto as an MCP server
- Workflow graphs
- Handoffs
- Peer mesh or swarm orchestration
- Typed context DSL
- Artifact delivery
- Tool exposure/gating
- Public strategy selection
- Raw Jido signals, directives, or state operations

## Baseline Assessment

Moto is ready for a serious baseline review. It is not ready to be treated as a
stable package. The spike has proven the core design direction: a narrow,
developer-friendly agent DSL can sit on top of Jido/Jido.AI without exposing most
of the low-level runtime machinery.

The best next move is to make the current package smaller at the edges, clearer
in the docs, and more predictable at runtime. New feature layers should wait.
