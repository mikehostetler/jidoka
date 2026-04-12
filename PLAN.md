# Jidoka Plan

## Intent

Jidoka is a standalone coding agent package for the Jido ecosystem.

It is inspired by Pi's shape as a practical coding harness:

- one agent/session kernel
- tool-using LLM loop
- durable session history
- resource loading from project files
- shell adapters such as CLI, TUI, RPC, or editor integration

Jidoka is not the same thing as `jido_code`, and it should not drift toward a cloud software factory, orchestration control plane, or hosted build system.

The package should stay focused on one local or remotely hosted coding session at a time.

## Product Definition

Jidoka should feel like:

- a coding session runtime
- a prompt and resource assembly layer
- a tool registry for file, shell, search, and project actions
- a persistence and replay model for coding conversations
- a shell-neutral backend that can drive terminal, desktop, RPC, or editor UX

The first user-facing experience should be a TUI.
That does not mean the runtime itself should be TUI-shaped.

Jidoka should not require a specific frontend.

## Pi-Inspired Characteristics To Preserve

The important Pi ideas are architectural, not language-specific:

1. A thin execution kernel with clear boundaries.
2. A session layer that owns persistence, compaction, and navigation.
3. Resource discovery from project files such as `AGENTS.md`, skills, templates, and settings.
4. A practical built-in toolset for coding work.
5. Multiple frontends over one common runtime.
6. Incremental context management instead of treating conversation history as an unbounded blob.

Jidoka should borrow those ideas while staying idiomatic to Jido and OTP.

## Core Decisions

### 1. Use `Jido.AI.Agent` for v1

Jidoka should build on `Jido.AI.Agent` for the initial LLM and tool loop.

Reasons:

- ReAct loop already exists.
- Request lifecycle already exists via `ask/await`.
- Mid-run steering already exists via `steer` and `inject`.
- Thread and context projection already exist.
- The expensive correctness work is already in `jido_ai`.

This avoids building a second LLM runtime in parallel.

### 2. Do not start with a custom strategy

For v1, Jidoka should not introduce a custom strategy unless a concrete mismatch appears.

The default ReAct behavior is already close to the needed model for a coding agent:

- submit a user request
- let the model inspect files and call tools
- feed tool results back into the loop
- allow steering while a run is active

Custom strategy work should only begin if Jidoka later needs different loop semantics, such as:

- multiple active conversation lanes in one session
- planner and executor phases as first-class strategy states
- subagent orchestration inside the reasoning loop itself
- native branch-aware execution semantics

### 3. Keep session behavior above the LLM loop

`Jido.AI.Agent` should remain the execution kernel.

Jidoka should own the layer above it:

- resource loading
- prompt assembly
- session persistence policy
- branch and navigation metadata
- compaction policy
- shell adapters

This keeps responsibilities legible and avoids turning `jido_ai` into a general coding harness package.

### 4. Keep `Jido.Thread` as the canonical append-only log

`agent.state[:__thread__]` should remain the source of truth for what happened.

Do not overload `Jido.Thread` with a Pi-style branch DAG.

Instead:

- keep the thread linear and append-only
- model branching and navigation in a separate session graph structure
- treat compaction and branch summaries as session-level projections and metadata

This matches Jido's persistence model better than forcing thread itself to become a tree.

### 5. Do not start with `Jido.Pod`

Jidoka should begin as a single durable session runtime, not a durable team topology.

Use `InstanceManager` for the durable unit.

Pods may become useful later for optional helpers such as:

- background indexing
- long-running retrieval workers
- delegated research or review agents

But they should not be the entry point.

### 6. Keep shell and filesystem dependencies optional until they pay for themselves

Jidoka should not depend on extra packages unless they remove real complexity in the first implementation slice.

For v1, Jidoka needs:

- a file tool boundary
- a shell tool boundary
- structured results
- room for later sandboxing or remote execution if the product grows into that need

That does not automatically mean it needs `jido_vfs` or `jido_shell` on day one.

Use them only if they clearly reduce v1 code:

- use `jido_vfs` if Jidoka needs backend-agnostic filesystem access, sandboxable path policy, or multiple storage backends
- use `jido_shell` if Jidoka needs PTY support, streaming shell sessions, cancellable process lifecycle management, or later remote shell backends

If v1 is strictly:

- local filesystem access
- local command execution
- no sandbox abstraction yet
- no remote shell transport yet

then Jidoka can start with thin local adapters of its own and keep the dependency surface smaller.

Do not make `jido_harness` or `jido_workspace` hard dependencies for v1.

They are promising and worth learning from, but today they overlap too much with Jidoka's intended ownership:

- `jido_harness` already defines provider-neutral CLI coding-agent contracts
- `jido_workspace` already explores workspace and snapshot lifecycle concerns

Jidoka should stay simpler at first:

- own the coding-session runtime
- keep room to adopt `jido_shell` and `jido_vfs` later if they clearly reduce complexity
- keep room to align with `jido_harness` or `jido_workspace` later if the boundaries become clearly complementary

### 7. Make the runtime signal-first and the TUI an adapter

Jidoka should be TUI-first in product delivery, but headless in runtime design.

That means:

- the session runtime should accept commands as structured events or signals
- the session runtime should emit structured events or signals for everything the UI needs to render
- the TUI should subscribe to those events and issue commands back into the runtime
- the same runtime should still work with no TUI attached

This keeps the agent abstracted from presentation and makes headless automation, remote control, and alternate frontends much easier.

## Proposed Namespace

Top-level namespace:

- `Jidoka`

Likely public modules:

- `Jidoka.Agent`
- `Jidoka.Runtime`
- `Jidoka.Resources`
- `Jidoka.Tools`
- `Jidoka.Compaction`
- `Jidoka.Branches`
- `Jidoka.SessionGraph`
- `Jidoka.Signals`
- `Jidoka.Bus`
- `Jidoka.CLI`
- `Jidoka.TUI`
- `Jidoka.RPC`

Possible supporting namespaces:

- `Jidoka.Resources.Skills`
- `Jidoka.Resources.Templates`
- `Jidoka.Resources.ContextFiles`
- `Jidoka.Tools.Builtin`
- `Jidoka.Tools.Policy`
- `Jidoka.Prompt`

## Ecosystem Package Guidance

Likely direct dependencies for v1:

- `jido`
- `jido_ai`

Recommended persistence dependency:

- `jido_bedrock` as the default durable persistence adapter, behind a Jidoka-owned adapter boundary

Useful later or optionally:

- `jido_vfs` if local file tools need to grow into backend-agnostic or policy-aware filesystem access
- `jido_shell` if shell execution needs PTY, streaming, cancellation, or remote backend support
- `jido_otel` for tracing and observability
- `jido_eval` for benchmark and quality regression workflows
- `jido_browser` only if browser automation becomes a real requirement

Packages to avoid depending on in the first slice unless a concrete need appears:

- `jido_harness`
- `jido_workspace`

Reason:

- they are both valuable, but each currently reaches into runtime surfaces that Jidoka itself is still trying to define
- v1 should avoid becoming a thin wrapper around a still-moving CLI stack
- Jidoka can still align its contracts so future interop stays possible

## Proposed Runtime Shape

### Session Kernel

The primary public runtime unit should be `Jidoka.Agent`.

`Jidoka.Runtime` should remain the internal execution engine.

It should likely wrap or use `Jido.AI.Agent` conventions and expose:

- `ask/await`
- `ask_sync`
- `steer`
- `inject`
- signal-oriented command ingress and event egress
- session open and close semantics
- current model and tool configuration

`Jido.Agent.InstanceManager` should manage named durable sessions.

Examples:

- one session per repo
- one session per worktree
- one session per user-workspace pair

### Persistence Boundary

Durability should be defined by an explicit session persistence contract, not by whatever happens to be resident in a live process.

Persist verbatim:

- append-only thread log
- session graph and branch metadata
- session configuration and adapter policy
- persisted memory checkpoints where needed
- resource manifest with source paths, digests, precedence, and trust decisions
- workspace metadata and external references

Recompute on resume:

- effective prompt text
- resolved tool registry
- resolved home and project resources
- ephemeral UI state
- in-flight request execution handles

`Jido.Agent.InstanceManager` should manage live named processes.
It should not be treated as the canonical persistence store.

Jidoka should define a persistence behavior such as:

- `Jidoka.Persistence`

Initial adapters:

- `Jidoka.Persistence.Memory` for tests and no-setup local runs
- `Jidoka.Persistence.Bedrock` backed by `jido_bedrock` for durable persistence

Bedrock should be the default durable adapter when persistent storage is enabled, but the adapter boundary must remain strict because the current ecosystem support level is still early.

### Thread

Use `Jido.Thread` as the canonical audit log.

Expected entry categories:

- user messages
- assistant messages
- tool calls and tool results
- session-level events
- context replacement and compaction markers
- branch-summary records
- shell or adapter lifecycle events where useful

The precise entry taxonomy can evolve, but the invariant should not:

- thread is append-only
- thread is the canonical audit log
- authoritative session state is thread plus persisted session metadata
- LLM context is projected from thread plus session state

### Memory

Use `Jido.Memory` for mutable cognitive and session state.

Memory is useful, but it must not become a second hidden source of truth beside the thread.

Likely spaces:

- `world`: current session facts, environment, policy, tool settings
- `tasks`: user-visible or internal work queue

Potential additional spaces:

- `resources`: loaded skills, templates, context files, package manifests
- `files`: read and modified file sets, editor/open-buffer metadata
- `session`: branch pointer, current view, compaction watermark
- `ui`: frontend-specific transient preferences if needed

Branch semantics should be explicit:

- `world`: branch-local facts projected from the current thread slice plus stable session configuration
- `tasks`: branch-local task queue and plan state
- `resources`: shared by session, versioned by source digest, recomputed on resume when sources change
- `files`: branch-local working-set metadata derived from tool events and workspace state
- `session`: branch-local navigation pointer, compaction watermark, and current leaf
- `ui`: adapter-local and non-durable unless an adapter opts in explicitly

Rehydration rule:

- branch navigation and session resume must rebuild branch-local memory from thread plus persisted session metadata or checkpoints, not from stale live process state

### Session Graph

Introduce a separate `Jidoka.SessionGraph` or equivalent structure for:

- branch points
- current leaf
- labels or bookmarks
- summary nodes
- navigation history

This is where Pi-style tree navigation belongs, not inside `Jido.Thread`.

## Resource Layer

Jidoka needs a first-class resource loader similar in spirit to Pi's.

It should discover and normalize:

- `AGENTS.md`
- project-local context files
- optional skill files and skill directories
- prompt templates
- tool presets or package declarations
- model or policy settings

Responsibilities:

- discover resources from cwd and ancestor directories
- discover user resources from `JIDOKA_HOME` or `~/.jidoka`
- merge built-in, user, project, and runtime-provided resources
- preserve source metadata, trust decisions, and precedence
- build the effective system prompt input

This suggests:

- `Jidoka.Resources.Loader`
- `Jidoka.Resources.ContextFiles`
- `Jidoka.Resources.Skill`
- `Jidoka.Resources.Template`

### Resource Precedence and Trust

Precedence should be deterministic from the first implementation slice.

Highest to lowest:

- runtime or adapter-provided overrides
- project-local resources
- user-home resources
- built-in defaults

Trust model for v1:

- built-in defaults are trusted
- user-home resources are trusted by default
- project resources may shape prompt and context
- project resources do not automatically widen tool permissions, change sandbox policy, or escalate adapter capabilities

Every loaded resource should carry:

- source path
- source digest
- precedence level
- trust decision

That metadata should be visible to observability and persistence layers.

## Local Home Directory

Jidoka should have a stable per-user home directory for config, trusted user resources, logs, and local state.

For v1:

- prefer `JIDOKA_HOME` when set
- otherwise use `~/.jidoka`

Suggested layout:

- `config.toml`
- `profiles/`
- `sessions/`
- `prompts/`
- `logs/`
- `cache/`
- `state/`

This home directory should hold:

- model defaults
- adapter settings
- user-level skills and templates
- persistence configuration
- durable local metadata that is not repo-local

Project resources should still override user-home resources according to the precedence rules above.

## Prompt Assembly

Jidoka should have an explicit prompt builder, not scattered string concatenation.

Prompt inputs should include:

- base system prompt
- project context files
- skill descriptions
- active tool descriptions and guidelines
- model-specific or frontend-specific append rules

This layer should produce:

- effective system prompt text
- structured prompt metadata for observability and debugging

Suggested module:

- `Jidoka.Prompt.Builder`

## Tooling Model

Jidoka tools should remain `Jido.Action` modules where possible.

Built-in coding tools should likely include:

- read
- write
- edit
- bash
- grep
- find
- ls

Additional optional tools:

- diff
- test runner
- formatter
- git status / git diff helpers
- project metadata inspection

Guidelines:

- prefer existing Jido action contracts
- keep file and shell tool boundaries backend-agnostic
- adopt `jido_vfs` only if filesystem abstraction pressure becomes real
- adopt `jido_shell` only if shell/session abstraction pressure becomes real
- keep tool results structured
- preserve tool-call ordering in the observable contract
- serialize conflicting file mutations by path when tool concurrency is enabled

## Shell Adapters

Jidoka should separate session runtime from shell or UI concerns.

Planned adapters:

- TUI
- PubSub or signal transport
- JSON or RPC transport
- CLI
- editor or desktop integration

Each adapter should:

- send user input into the session agent
- receive structured events back
- render them appropriately

The session runtime should not depend on a specific UI library.

If Jidoka later needs PTY, streaming shell sessions, cancellation semantics, or remote shell adapters, `jido_shell` becomes a strong candidate backend.

## Signals and Event Bus

Jidoka should treat signals as the canonical inter-process envelope at the runtime boundary.

Use `Jido.Signal` for:

- user intents such as ask, steer, cancel, navigate, branch, resume
- session lifecycle events
- tool lifecycle events
- assistant output events
- adapter control messages where useful

Signal-first does not mean every internal function call must go through a transport layer.
It means every important external interaction should have a signal form.

PubSub should be an adapter concern, not the source of truth.

Recommended shape:

- session runtime keeps authoritative state in thread, memory, and persistence
- runtime emits session events as signals
- `Jidoka.Bus` should be a thin Jidoka facade over `Jido.Signal.Bus` plus optional PubSub fanout
- `Jidoka.Bus` publishes those signals to local or distributed subscribers
- adapters subscribe to topics and project them into UI state
- adapters send commands back through the same signal-shaped ingress used by public API wrappers

Phoenix.PubSub is a strong default bus because it can run standalone in the supervision tree and Jido signal dispatch already supports a `:pubsub` adapter.

Suggested topic model:

- `jidoka.session.<session_id>.events`
- `jidoka.session.<session_id>.commands`
- `jidoka.session.<session_id>.presence`

This gives Jidoka:

- TUI-first UX without coupling the runtime to terminal rendering
- headless operation over PubSub
- direct same-process operation without PubSub when simpler
- future multi-view or remote adapter support

## TUI Direction

Jidoka should ship its first frontend as a TUI, but keep the TUI thin.

The TUI should own:

- layout
- focus and pane state
- keyboard shortcuts
- viewport and scroll state
- local presentation concerns

The runtime should own:

- session state
- request lifecycle
- tool execution
- persistence
- compaction
- branch and navigation semantics

The TUI should consume a projected session view built from signals and occasional direct queries.

This keeps rendering concerns out of the session core and makes it feasible to run the same agent headless or from another frontend.

## Compaction

Jidoka needs explicit context management from the start, even if v1 is simple.

Compaction should be modeled as:

- a session-level operation
- a thread-backed event
- a deterministic replacement of projected LLM context

For v1:

- keep compaction manual or threshold-triggered
- summarize old context into a compact replacement snapshot
- append compaction provenance to the thread

Do not build overly ambitious semantic memory first.
Get deterministic context replacement working before clever summarization layers.

## Branching and Navigation

Branching is important for a coding harness, but it should be implemented carefully.

Needed features:

- fork current session position
- navigate to prior branch points
- summarize abandoned branch work
- preserve labels and bookmarks

Branching rules:

- thread remains append-only
- branch metadata lives in session graph
- summaries are durable artifacts, not ephemeral UI notes

## Suggested Public API Direction

Examples of the shape Jidoka may want:

```elixir
{:ok, pid} = Jidoka.start_session(id: "repo-main", cwd: "/path/to/repo")

{:ok, request} = Jidoka.ask(pid, "inspect the failing tests and propose a fix")
{:ok, result} = Jidoka.await(request, timeout: 30_000)

:ok = Jidoka.steer(pid, "focus on the auth failure first", expected_request_id: request.id)

{:ok, branch_id} = Jidoka.branch(pid, label: "before-refactor")
{:ok, _} = Jidoka.navigate(pid, branch_id, summarize: true)
```

The exact surface can change, but the package should read like a session runtime, not a generic model facade.

## Test Strategy

Jidoka needs an explicit test strategy from the first implementation slice.

No roadmap phase should be considered complete until the matching invariants are covered by tests.

Required test layers:

1. Invariant tests
   - append-only thread replay
   - deterministic prompt projection from the same inputs
   - session resume equivalence
   - compaction equivalence
   - branch rehydration correctness
2. Contract tests
   - `Jidoka.Persistence` adapter contract
   - Jidoka file tool adapter contract
   - Jidoka shell tool adapter contract
   - event ordering and error-shape guarantees
3. Integration tests
   - headless session flows against fixture repos
   - steering during active runs
   - resource discovery from home plus project scope
   - resume after restart
   - TUI adapter against a headless runtime over signals or PubSub
4. Recovery and safety tests
   - crash during tool execution
   - partial persistence writes
   - conflicting file mutations
   - adapter timeouts or cancellation
5. Golden transcript tests
   - representative coding sessions with expected event streams and persisted artifacts

Optional later layer:

- `jido_eval`-based benchmark and quality regression suites once that package is mature enough for Jidoka's needs

## Roadmap

### Phase 1: Headless Session Runtime

Goal:

- one durable session agent
- one built-in ReAct loop via `Jido.AI.Agent`
- minimal coding tools
- durable thread and memory

Deliverables:

- `Jidoka.Agent`
- `Jidoka.Runtime`
- `Jidoka.Persistence` with in-memory adapter
- built-in read/write/edit/bash tools behind Jidoka-owned file and shell boundaries
- basic prompt builder
- basic resource loader for `AGENTS.md`
- initial `JIDOKA_HOME` or `~/.jidoka` discovery
- invariant tests for replay, prompt assembly, and resume shape

### Phase 2: Session Persistence, TUI, and Transport API

Goal:

- make Jidoka usable from a TUI and one programmatic transport without changing the runtime model

Deliverables:

- session open and resume semantics
- `Jidoka.Persistence.Bedrock`
- `Jidoka.Bus`
- signal-based event contract for adapters
- initial TUI workflow
- stable event contract for adapters
- basic PubSub transport
- basic JSON or RPC transport
- contract tests for persistence, file, and shell adapters
- integration tests for TUI against headless runtime over signals or PubSub
- decide whether `jido_vfs` or `jido_shell` are justified by actual adapter pressure

### Phase 3: Compaction and Session Graph

Goal:

- prevent context blow-up
- support branch-aware coding sessions

Deliverables:

- `Jidoka.Compaction`
- `Jidoka.SessionGraph`
- branch summary artifacts
- navigation APIs
- branch rehydration and compaction equivalence tests

### Phase 4: Skills, Templates, and Packages

Goal:

- make project behavior extensible without patching core

Deliverables:

- skill loading
- prompt templates
- package or extension manifests
- configurable tool policies
- precedence and trust fixture tests across built-in, home, and project resources

### Phase 5: Optional Advanced Orchestration

Goal:

- support background helpers or delegated specialists without forcing them into v1

Deliverables:

- optional helper agents
- optional pod-backed helpers if justified
- richer plan and review workflows
- optional `jido_eval` quality suites if they add signal without overcomplicating the stack

## Risks and Open Questions

### 1. Branch model complexity

Pi's session tree is useful, but implementing it directly in core thread storage would be a mistake.

Open question:

- how much of the tree model belongs in v1 versus a later phase?

### 2. Tool concurrency and file safety

Parallel tool execution is attractive, but unsafe file mutation semantics will corrupt user work.

Need:

- clear mutation queue by canonical file path
- predictable result ordering

### 3. Resource trust boundary

Loading project skills and prompts means executing untrusted instructions indirectly through the agent.

Need:

- explicit trust model
- source metadata
- predictable precedence rules

### 4. Checkpoint and resume boundary

Open question:

- is `Jido.AI.Agent` enough for Jidoka session resume, or should some flows use standalone `Jido.AI.Reasoning.ReAct` checkpoint tokens under the hood?

Initial answer:

- start with `Jido.AI.Agent`
- adopt standalone ReAct only if cross-process resume or external stream orchestration becomes a real requirement

### 5. Persistence adapter maturity

`jido_bedrock` is attractive for default durable persistence, but it is still an early ecosystem package.

Need:

- keep the `Jidoka.Persistence` boundary strict
- support an in-memory adapter for tests and bootstrap flows
- avoid leaking Bedrock-specific assumptions into the public session API

## Recommended First Implementation Slice

Build the smallest slice that proves the shape:

1. `Jidoka.Agent` using an internal `Jidoka.Runtime` over `Jido.AI.Agent`
2. `Jidoka.Persistence` with in-memory and Bedrock adapters
3. built-in coding tools: read, edit, write, bash behind thin Jidoka-owned adapters
4. signal-shaped session commands and events
5. `AGENTS.md` plus `JIDOKA_HOME` discovery and prompt assembly
6. thread-backed transcript, request lifecycle, and explicit resume contract
7. invariant and contract tests for replay, persistence, resource precedence, and event ordering

If that feels right in practice, add:

8. first TUI adapter over direct calls or PubSub
9. grep/find/ls tools
10. adopt `jido_vfs` or `jido_shell` only if the adapter surface is clearly outgrowing local implementations
11. compaction
12. session graph and branch navigation

## Summary

Jidoka should be a standalone coding session runtime for Jido.

It should:

- reuse `jido_ai` for the LLM and tool loop
- use Jido signals as the external event envelope
- isolate persistence behind a Jidoka-owned adapter, with Bedrock as the default durable backend
- keep Jido's thread and memory model intact
- add a Pi-inspired session layer above the loop
- use a per-user home directory for trusted config and resources
- deliver TUI first while keeping the runtime headless and adapter-driven
- stay frontend-neutral
- ship with an obligatory invariant-driven test strategy
- keep shell and filesystem dependencies optional until the abstraction pressure is real
- remain focused on coding sessions, not cloud orchestration

The critical design rule is simple:

- `jido_ai` owns execution
- Jidoka owns the coding session
