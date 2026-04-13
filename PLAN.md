# Jidoka Plan

## Direction

Jidoka should start as a local-first, OTP-native TUI agent for durable coding tasks.

The MVP is not a generic orchestration platform.

It is a terminal-first system for one operator to:

- open a session for a workspace
- submit a coding task
- run one attempt in one isolated writable environment
- watch progress stream in real time
- inspect diffs, logs, and verifier output
- decide whether to approve, retry, reject, or cancel
- resume safely after interruption

The long-term architecture should still leave room for:

- child runs
- richer coordination
- additional task packs
- alternate execution kernels

But those are expansion paths, not MVP commitments.

## Product Definition

Jidoka should feel like a durable terminal workspace for coding tasks.

The core runtime owns:

- session lifecycle
- run lifecycle
- attempt lifecycle
- environment leasing
- verifier gating
- artifact persistence
- typed events and snapshots

`Jidoka.Coding` is the first and only task pack in the MVP.

The TUI is the first and only frontend in the MVP.

## MVP

The MVP supports one clear loop:

1. Open a session for a repo or workspace.
2. Submit one coding task.
3. Create one isolated writable environment lease.
4. Run one attempt through one execution kernel adapter.
5. Stream tool and execution events into the TUI.
6. Run a verifier plan.
7. Persist diff, log, transcript, and verifier artifacts.
8. Let the operator approve, retry, reject, or cancel.
9. Persist the final run outcome and make the session resumable.

This is enough to prove the product.

## What The MVP Does Not Need

The following should be explicitly deferred:

- generic task-pack infrastructure beyond what `Jidoka.Coding` needs
- full multi-agent orchestration
- run graph machinery
- merge engines and handoff frameworks
- multiple environment providers
- multiple frontend adapters
- advanced compaction
- provider marketplaces
- rich policy inheritance trees
- branch-like navigation as a primary user concept

If a capability does not improve the single-operator coding loop, it should not be in the MVP.

## Design Rules

1. Data first, process second.
2. Persist authoritative state as typed data.
3. No live process state is authoritative if it cannot be rebuilt.
4. One durable entity should have one clear writer.
5. Verification and operator approval gate success.
6. Environment isolation lands before branch-like navigation.
7. The runtime remains headless even though the TUI is first-class.
8. The root namespace owns orchestration; `Jidoka.Coding` owns coding behavior.
9. Model future child-run support in data, but do not implement it in MVP behavior.
10. Choose the smallest OTP topology that keeps ownership obvious.

## Durable Data Model

The MVP should keep the durable model small.

Required first-class structs:

- `Jidoka.Session`
- `Jidoka.Run`
- `Jidoka.Attempt`
- `Jidoka.Artifact`
- `Jidoka.EnvironmentLease`
- `Jidoka.VerificationResult`
- `Jidoka.Outcome`
- `Jidoka.Event`

Every durable struct should have:

- a stable `id`
- a `version`
- explicit timestamps
- an explicit status or outcome field
- a documented ownership boundary

Typed structs matter more than the schema library behind them.

A library such as Zoi may back these structs if it helps with validation and evolution, but the schema layer is not the product architecture.

### Session

A durable envelope for a workspace and its runs.

A session owns:

- workspace identity
- session metadata
- run index
- event stream reference
- snapshot metadata

### Run

A run is the durable record for one submitted coding task.

A run owns:

- task text or task spec
- selected task pack
- current status
- current or latest attempt id
- verifier plan reference
- artifact references
- final outcome

The MVP only needs root runs, but the struct may reserve fields such as:

- `parent_run_id`
- `role`

Those fields are for future expansion and should not drive MVP behavior.

Suggested run statuses:

- `queued`
- `running`
- `awaiting_approval`
- `completed`
- `failed`
- `canceled`

### Attempt

An attempt is one execution pass for a run.

An attempt owns:

- attempt input snapshot
- environment lease reference
- execution status
- execution metadata
- artifact references
- verification result reference

Suggested attempt statuses:

- `pending`
- `running`
- `succeeded`
- `retryable_failed`
- `terminal_failed`
- `canceled`

### Artifact

Artifacts are durable records emitted during or after an attempt.

Initial artifact types:

- diff
- transcript
- verifier report
- command log
- prompt or execution report

### EnvironmentLease

An environment lease records who can mutate which workspace copy.

The MVP only needs one write-capable lease mode:

- `exclusive`

### VerificationResult

A verification result should be typed and durable.

Suggested result kinds:

- `passed`
- `retryable_failed`
- `terminal_failed`

### Event

Events are append-only facts emitted by the runtime.

Events should be typed enough to support:

- TUI streaming
- recovery
- auditability
- snapshot invalidation

Snapshots remain derived read models, not the source of truth.

## Runtime Topology

The MVP should use the smallest OTP topology that keeps ownership clear.

### Application Tree

Start with:

- `Jidoka.Registry`
- `Jidoka.SessionSupervisor`
- `Jidoka.AttemptSupervisor`
- `Jidoka.Bus`
- persistence support processes if needed

### SessionServer

`Jidoka.SessionServer` should be the single durable writer in the MVP.

It owns:

- session state
- run records
- attempt records
- environment lease records
- outcome transitions
- snapshot generation

Responsibilities:

- accept submit, approve, retry, reject, and cancel commands
- validate state transitions
- persist durable changes
- start and track attempt workers
- record artifact and verification results
- expose session and run snapshots
- support session resume

This is the key simplification for the MVP.

Do not split durable write ownership across multiple runtime processes yet.

### AttemptWorker

`Jidoka.AttemptWorker` should execute one attempt.

Responsibilities:

- receive a typed attempt spec
- use the leased environment
- call the execution kernel adapter
- stream typed events back to the session
- report completion, failure, and artifact metadata
- trigger verifier execution or return enough data for verification

An attempt worker should not be a second durable writer.

### TuiServer

`Jidoka.TuiServer` should own terminal interaction state, not durable runtime truth.

Responsibilities:

- subscribe to session events
- render focused session and run views
- manage input modes
- handle operator commands
- reconnect to an existing session after restart
- batch rendering so streams do not thrash the terminal

### Optional Environment Manager

If environment lifecycle becomes complex, add a small manager process.

Do not introduce it before lease lifecycle actually needs separate ownership.

### Explicitly Not In MVP Topology

Do not introduce these as first-pass requirements:

- `Jidoka.RunServer`
- `Jidoka.DelegationCoordinator`
- `Jidoka.RunGraphProjector`
- separate merge coordinators

Those may arrive later if concurrency or child-run coordination truly demands them.

## Command Flow

The core flow should stay legible:

1. The operator submits a coding task from the TUI.
2. `Jidoka.SessionServer` creates a `Run`.
3. The session creates an isolated `EnvironmentLease`.
4. The session creates an `Attempt`.
5. The session starts an `AttemptWorker`.
6. The attempt worker streams typed events.
7. The verifier runs.
8. The session records artifacts and verification results.
9. The run moves to `awaiting_approval`, `failed`, or `completed`.
10. The operator approves, retries, rejects, or cancels.

The runtime should make each transition explicit and durable.

## Execution Boundary

The execution kernel is an internal adapter, not the public runtime model.

Suggested boundary:

- `Jidoka.Execution`
- `Jidoka.Execution.<KernelName>`

The execution boundary should accept typed attempt input and return typed execution output.

The kernel should not define:

- public orchestration terminology
- session lifecycle
- run lifecycle
- approval semantics
- persistence shape

The kernel is one replaceable engine inside the attempt flow.

## Coding Pack Boundary

`Jidoka.Coding` is the first task pack and the only MVP task pack.

It owns:

- repo-oriented task normalization
- project instruction loading
- coding context assembly
- tool profile selection
- verifier plan selection
- diff interpretation
- coding-specific artifact summaries

It should not own:

- session lifecycle
- run persistence
- retry state transitions
- terminal rendering

The interface should be narrow.

Do not build a large generic task-pack behavior until a second pack justifies it.

## Environment Model

Environment isolation is mandatory in the MVP.

The MVP only needs one writable environment type:

- `:isolated_repo`

The implementation may use:

- a worktree
- a copied workspace

That choice is a provider detail, not a top-level product concept.

Rules:

- every write-capable attempt must have an explicit environment lease
- the lease must be persisted
- the operator should be able to see which environment backs the attempt
- cleanup behavior must be explicit
- concurrent writers are out of scope for MVP

No branch-like navigation should ship before isolated writable environments work reliably.

## Verification And Approval

Verification is part of the MVP product, not a later hardening pass.

Every mutable coding task should end in one of these states:

- verifier passed, awaiting operator approval
- verifier failed but retryable
- verifier failed terminally
- canceled

The operator actions should be explicit:

- `approve`
- `retry`
- `reject`
- `cancel`

This is simpler and more useful than early merge machinery.

If the system later adds child runs, approval and merge semantics can grow from this base.

## TUI Requirements

The TUI should be treated as a first-class operational surface.

Minimum capabilities:

- session list or current session picker
- focused run view
- live transcript or event pane
- artifact pane for diff, logs, and verifier output
- status line for run, attempt, and environment lease
- approval and retry controls
- interrupt or steer input
- reconnect to an in-progress session

The TUI should not own durable state.

It renders snapshots and reacts to events.

## Persistence And Snapshots

The persistence boundary should be strict and boring.

Persist:

- sessions
- runs
- attempts
- environment leases
- artifacts
- verification results
- outcomes
- typed events or enough transition records to reconstruct state

Rebuild on resume:

- process pids
- subscriptions
- terminal state
- render caches
- ephemeral handles

Snapshots are derived read models for the TUI.

The rule is:

- persisted data owns truth
- events describe change
- snapshots serve rendering

## Evaluation

Evaluation should exist early, but it does not need a large framework in the MVP.

Start with a small fixture corpus that proves:

- a coding task can run end to end
- a verifier can pass or fail
- a session can resume after interruption
- artifacts are persisted and inspectable

This is enough to tell whether the architecture is helping.

## Roadmap

### Phase 0: Trim And Commit The MVP Direction

Goal:

- replace the broad platform plan with a TUI-first coding-agent MVP

Deliverables:

- this trimmed plan
- clear MVP and non-MVP scope
- explicit ownership and persistence rules

### Phase 1: Durable Single-Run Backend

Goal:

- prove the runtime can execute one coding task safely

Deliverables:

- typed session, run, attempt, artifact, lease, verification, outcome, and event structs
- `Jidoka.SessionServer`
- `Jidoka.AttemptWorker`
- one execution kernel adapter
- one isolated writable environment provider
- one verifier path
- persistence adapter with resume support

### Phase 2: TUI Completion Loop

Goal:

- make the product usable from the terminal

Deliverables:

- focused run view
- live event streaming
- artifact inspection
- approve, retry, reject, and cancel controls
- reconnect behavior
- stable snapshots for rendering

### Phase 3: Hardening And Fixtures

Goal:

- make the MVP trustworthy

Deliverables:

- fixture corpus
- resume and recovery tests
- cleanup guarantees for isolated environments
- artifact retention policy
- latency and verification metrics where practical

### Phase 4: Expansion

Goal:

- extend the system only after the single-run loop proves useful

Possible deliverables:

- child runs
- reviewer-style delegated runs
- richer policy controls
- alternate execution kernels
- additional task packs
- additional frontends

## Expansion Path

The MVP should leave room for later child-run coordination without forcing it early.

To do that:

- allow `Run` to carry optional `parent_run_id` and `role`
- keep event types expressive enough for future delegation
- keep snapshots capable of rendering more than one run
- keep the execution boundary task-pack agnostic

But do not introduce:

- general run graphs
- merge engines
- handoff frameworks
- coordination supervisors

until real usage proves they are needed.

## Summary

Jidoka should begin as:

- a local-first, OTP-native TUI agent
- for durable coding tasks
- with a small typed data model
- with one clear durable writer
- with isolated writable environments
- with verifier-gated and operator-gated completion

The core rule for the MVP is:

- session owns durable coordination
- attempt owns one execution pass
- coding pack owns coding behavior
- TUI owns interaction
- persisted data owns truth

That is a real MVP and still leaves a clean path toward richer orchestration later.
