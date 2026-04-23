# Moto Roadmap

Updated: 2026-04-23

This roadmap is the high-level guide for moving Moto toward beta and then into
the next orchestration layers. `TODO.md` remains the tactical checklist; this
file explains sequencing, scope, and boundaries.

## Product Direction

Moto should stay a narrow, developer-friendly layer over Jido and Jido.AI. The
core design line is:

- `agent` is the executable unit.
- `workflow` coordinates explicit multi-step work.
- `character` shapes identity, voice, and prompt persona.
- `handoff` transfers conversation/control ownership.
- `team` or `pod` represents a durable supervised group.

Do not let `Moto.Agent` absorb every concept. The package should grow by adding
clear adjacent nouns, not by turning the agent DSL into a catch-all runtime.

## Milestone Order

### 1. Workflow Spike With `jido_runic`

Goal: prove the workflow substrate before committing the public Moto API.

Status: done.

Scope:

- Use the local `../jido_runic` checkout as a path dependency in a feature
  branch.
- Build the smallest Moto-owned proof that can compile a workflow and run it.
- Decide whether Moto should use direct `Runic.Workflow` execution,
  `Jido.Runic.Strategy`, or both.
- Decide how Moto agent calls become workflow nodes.
- Identify any required upstream changes in `jido_runic`.

Exit criteria:

- One tiny local workflow runs end-to-end.
- We know the runtime path for the MVP.
- We have a short design note for the public `Moto.Workflow` shape.

### 2. Workflow MVP

Goal: land the missing beta feature.

Status: done.

Scope:

- Add `Moto.Workflow`.
- Support workflow id, description, input schema, steps, dependencies, output
  selection, and inspection.
- Support agent-backed steps and deterministic function/action steps.
- Compile Jido Action-backed steps through `Jido.Runic.ActionNode` where that is
  the right fit.
- Return Moto/Splode errors.
- Add one focused example that is not the kitchen sink.
- Add docs explaining when to use an agent, subagent, or workflow.

Out of scope:

- Durable persistence.
- Planner-generated workflows.
- Crew/team abstraction.
- Public raw Runic graph authoring.

### 3. Runtime Error Normalization

Goal: make every important runtime failure readable and predictable before beta.

Scope:

- Normalize workflow errors into `Moto.Error`.
- Normalize subagent failures.
- Normalize MCP endpoint startup, command, conflict, and partial-sync failures.
- Normalize memory read/write failures and define which failures are soft vs
  hard.
- Ensure CLI demos call `Moto.format_error/1`.
- Add stable tests for multi-error formatting.

Ordering note:

Do this after the workflow MVP so workflow errors are included in the same error
taxonomy. Otherwise the error design will need to be reopened immediately.

Detailed plan:

1. Define the runtime error contract.
   - Keep public runtime calls returning `{:ok, value}` or
     `{:error, %Moto.Error.*{}}`.
   - Treat raw strings, atoms, tuples, exits, and third-party exceptions as
     internal causes that must be wrapped before crossing a Moto public
     boundary.
   - Preserve original reasons under `details.cause` or a narrower
     context-specific key so debugging does not lose information.
   - Standardize core metadata keys:
     `:operation`, `:agent_id`, `:workflow_id`, `:step`, `:target`, `:phase`,
     `:field`, `:value`, `:timeout`, `:request_id`, `:cause`.

2. Add a normalization module.
   - Introduce `Moto.Error.Normalize` as the single place that turns known raw
     runtime reasons into `Moto.Error.ValidationError`,
     `Moto.Error.ConfigError`, or `Moto.Error.ExecutionError`.
   - Keep the existing constructors in `Moto.Error`, but route boundary code
     through named normalizers such as:
     `chat_error/2`, `workflow_error/2`, `subagent_error/2`,
     `mcp_error/2`, `memory_error/2`, `hook_error/2`, and
     `guardrail_error/2`.
   - Make unknown shapes deterministic by wrapping them as execution or
     internal errors with the inspected cause in details.

3. Improve formatting.
   - Expand `Moto.Error.format/1` so it formats Splode classes, multi-errors,
     nested causes, workflow step failures, subagent failures, MCP endpoint
     failures, and memory failures.
   - Keep formatting stable and user-facing: one short headline plus sorted
     field bullets for validation details.
   - Ensure CLI demos and debug summaries never fall back to raw `inspect/1`
     for known Moto errors.

4. Normalize workflow errors first.
   - Audit `Moto.Workflow.Runtime` for raw reasons produced by input parsing,
     context refs, imported-agent refs, action execution, agent execution,
     timeouts, invalid step results, and output selection.
   - Ensure every `Moto.Workflow.run/3` error has workflow id, step name when
     applicable, target, operation, and original cause.
   - Add formatting tests for invalid input, missing context refs, missing
     imported agents, step failure, timeout, and invalid output refs.

5. Normalize subagent errors.
   - Replace public `{:subagent_failed, name, reason}`,
     `{:child_error, reason}`, `{:peer_not_found, peer}`, timeout, invalid
     task, invalid child result, and peer mismatch shapes with
     `Moto.Error.ExecutionError` or `Moto.Error.ValidationError`.
   - Preserve child request metadata and peer target details in error metadata.
   - Update parent-agent tests so subagent failures are asserted as structured
     Moto errors and formatted messages are stable.

6. Normalize MCP errors.
   - Wrap endpoint registration conflicts, startup failures, sync failures,
     command failures, tool limit failures, missing `jido_ai`, partial sync
     errors, and generated tool validation failures.
   - Distinguish hard failures from partial sync warnings. Hard failures should
     return `{:error, %Moto.Error.*{}}`; partial sync should return successful
     sync metadata with structured warning entries.
   - Add tests for conflict, startup failure, partial sync, missing dependency,
     and endpoint command errors.

7. Normalize memory errors.
   - Define which memory failures are hard:
     invalid memory config, missing required context namespace keys, invalid
     namespace setup, and write failures when persistence was explicitly
     requested.
   - Define which memory failures are soft:
     optional retrieval misses, empty memory, and disabled/missing plugin cases
     that should not stop an agent turn.
   - Wrap `jido_memory` and Jido plugin errors with agent id, namespace,
     lifecycle phase, and original cause.
   - Add tests around retrieve/build/persist phases and kitchen sink memory
     behavior.

8. Normalize hooks and guardrails.
   - Wrap invalid request refs, invalid stages, hook callback failures,
     guardrail callback failures, guardrail tool errors, interrupts, and
     invalid callback return shapes.
   - Keep interrupt semantics explicit: interrupts should remain interrupt
     outcomes where expected, but invalid interrupt shapes should become
     validation errors.

9. Build an error matrix test suite.
   - Add table-driven tests that exercise each public runtime boundary:
     `Moto.chat/3`, `Moto.Agent.prepare_chat_opts/2`,
     `Moto.Workflow.run/3`, subagent tools, MCP sync, and memory lifecycle.
   - Assert both struct class and formatted output.
   - Add regression tests proving unknown raw errors are wrapped rather than
     leaked.

10. Update docs and examples.
    - Document `Moto.format_error/1` as the recommended display path.
    - Add a short README section showing validation, config, and execution
      errors.
    - Update usage rules to say public runtime APIs return Moto/Splode errors
      and examples should not pattern-match on raw internal tuples.

Exit criteria:

- Public Moto runtime APIs do not leak known raw string/atom/tuple reasons.
- `Moto.format_error/1` produces stable messages for validation, config,
  execution, multi-error, workflow, subagent, MCP, memory, hook, and guardrail
  failures.
- Existing demos print formatted errors.
- The full release gate passes.

### 4. Public API Stabilization

Goal: freeze the beta public surface.

Scope:

- Review all public modules and function names.
- Decide top-level API boundaries, especially `Moto.chat/3`,
  `Moto.Workflow.run/3`, and whether a broader `Moto.run/3` belongs in beta.
- Ensure docs use `instructions`, not `system_prompt`, except for internal Jido
  mapping notes.
- Ensure examples use the beta DSL shape and parenless style.
- Confirm imported JSON/YAML specs match the beta section layout.
- Update README, usage rules, changelog, docs groups, and package metadata.
- Run the full release gate and demo smoke checks.

Exit criteria:

- The beta API is documented and intentionally named.
- Tactical TODO items blocking beta are either done or explicitly deferred.

### 5. Beta Release

Goal: publish or tag a coherent beta that users can evaluate.

Scope:

- Final release gate.
- Changelog and migration note for the beta DSL.
- Dependency posture decision:
  - internal beta can tolerate path/GitHub dependencies;
  - public Hex beta should prefer Hex releases or pinned tags.
- Release notes that clearly state what is stable, experimental, and deferred.

## Post-Beta Milestones

### 6. Characters Via `jido_character`

Goal: add persona/voice composition without bloating `Moto.Agent`.

Candidate package:

- `jido_character` exists at `https://github.com/agentjido/jido_character`.
- It is not currently available through `mix hex.info jido_character`.
- It provides Zoi-validated character maps, `use Jido.Character`, identity,
  personality, voice, knowledge, memory, instructions, renderers, and ReqLLM
  context rendering.

Likely Moto scope:

- Add `defaults.character MyApp.Characters.SupportAdvisor` or similar.
- Compose rendered character output with `defaults.instructions`.
- Define precedence between static instructions, dynamic instructions, and
  character-rendered prompt sections.
- Keep character memory distinct from `jido_memory` until the model is clear.

Risk:

- Character rendering touches prompt composition, which is public and easy to
  overfit. Do a small spike before adding public DSL.

### 7. Handoffs

Goal: support explicit control transfer between agents.

Distinction:

- Subagents are "agent as tool": the parent agent remains in control.
- Handoffs transfer ownership of the next turn or phase to another agent.

Scope questions:

- Who owns the thread after handoff?
- How is memory namespace selected?
- Which context keys are forwarded?
- Which guardrails and hooks apply after transfer?
- Does control ever return automatically?
- How is the final response surfaced?

Dependency:

- Workflows should land first so multi-step orchestration is not confused with
  conversation ownership transfer.
- Characters should land first or in parallel if handoff examples depend on
  strong specialist identity.

### 8. Pods And Durable Teams

Goal: expose durable supervised agent groups when users need long-lived teams or
workspace-level topology.

Underlying runtime:

- Jido Pods model canonical topology, eager/lazy node reconciliation, adoption,
  nested pods, partitioning, and runtime mutation.

Likely Moto noun:

- Prefer `team` publicly unless direct `pod` language proves clearer for
  Elixir/Jido users.

Scope:

- Define named team members.
- Start or lookup durable teams by id.
- Inspect member status.
- Ensure lazy members.
- Decide how teams interact with workflows and handoffs.

Out of scope for first pass:

- Full topology mutation DSL.
- Complex nested teams.
- Swarm-like peer mesh behavior.

### 9. Crew-Style Recipes

Goal: provide higher-level coordination patterns after the underlying pieces are
stable.

Positioning:

- CrewAI is useful as product vocabulary: agents, tasks, crews, flows, manager
  process, planning, memory, and callbacks.
- Moto should not copy YAML-first authoring or role/goal/backstory as the core
  DSL.
- Crew-style behavior should be built from Moto primitives:
  `agent + workflow + character + handoff + team`.

Possible recipes:

- Research-and-write team.
- Manager/reviewer/executor team.
- Planning workflow with specialist handoffs.
- Durable workspace team backed by Pods.

## Current Priority

The next work should follow this order:

1. Runtime error normalization.
2. Public API stabilization.
3. Beta release prep.

Characters, handoffs, Pods, and Crew-style coordination are important, but they
should not block the first beta unless the beta positioning explicitly requires
them.
