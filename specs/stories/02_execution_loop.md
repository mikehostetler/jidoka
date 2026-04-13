# Execution Loop Stories

### ST-MVP-004 Submit coding runs and allocate isolated environment leases

#### Goal

Make the runtime capable of accepting a single coding task and turning it into a durable run with an isolated writable environment.

#### Scope

- Add the submit command for a coding task.
- Create the durable `Run` and initial `Attempt` records.
- Allocate and persist an isolated write-capable environment lease for the attempt.

#### Acceptance Criteria

- The runtime accepts a submitted coding task and persists a new run with task pack `Jidoka.Coding` or equivalent coding-pack identity.
- Submitting a task creates an initial attempt record linked to the run.
- A write-capable environment lease is created and persisted before execution begins.
- The lease exposes enough metadata to identify the backing workspace copy or worktree path.
- Session or run snapshots show run status, latest attempt status, and active lease details.
- Tests cover submit flow, durable run and attempt creation, and lease persistence.

#### Dependencies

- `ST-MVP-003`

#### Out Of Scope

- Executing the attempt.
- Verifier behavior.
- Approval and retry commands.

### ST-MVP-005 Add execution adapter boundary and attempt worker streaming

#### Goal

Separate orchestration from execution and make attempt progress visible as typed runtime events.

#### Scope

- Add the execution boundary and one concrete adapter.
- Add `Jidoka.AttemptWorker` or equivalent attempt execution process.
- Stream typed attempt lifecycle and progress events back to the session.

#### Acceptance Criteria

- The runtime defines an execution boundary that accepts typed attempt input and returns typed execution output.
- `Jidoka.AttemptWorker` receives a typed attempt spec, uses the lease information it is given, and invokes the execution adapter.
- The attempt worker emits typed start, progress, completion, and failure events through the runtime event path.
- `Jidoka.SessionServer` remains the only durable writer; the worker reports state changes back rather than mutating persistence directly.
- Tests with a fake or stub adapter cover the expected event sequence and resulting attempt status changes.

#### Dependencies

- `ST-MVP-004`

#### Out Of Scope

- Verifier plan execution.
- TUI rendering.

### ST-MVP-006 Add verifier pipeline and verification results

#### Goal

Make completion quality explicit by running a verifier after attempt execution and storing the result durably.

#### Scope

- Add verifier-plan selection for coding runs.
- Execute verification after the attempt finishes.
- Persist and expose typed verification results.

#### Acceptance Criteria

- A coding run selects or derives a verifier plan before or during attempt execution.
- When an attempt finishes, verification runs automatically and produces a durable `VerificationResult`.
- Verification results are linked to the attempt and reflected in run state.
- The run moves to `awaiting_approval` when verification passes.
- The run moves to a retryable or terminal failure state when verification fails.
- Tests cover passing, retryable failing, and terminal failing verifier outcomes.

#### Dependencies

- `ST-MVP-005`

#### Out Of Scope

- Operator approval controls.
- TUI artifact browsing.

### ST-MVP-007 Support operator actions approve, retry, reject, and cancel

#### Goal

Complete the MVP control loop by making operator decisions explicit durable commands.

#### Scope

- Add operator commands for approve, retry, reject, and cancel.
- Enforce legal run and attempt transitions.
- Ensure retries create fresh isolated execution attempts.

#### Acceptance Criteria

- The runtime exposes operator commands for approve, retry, reject, and cancel.
- Approve finalizes the run outcome and seals the accepted artifact set.
- Retry creates a new attempt with a fresh isolated environment lease or an explicitly reset writable environment.
- Reject records a rejected terminal outcome without mutating prior attempt artifacts.
- Cancel stops an in-flight attempt when possible and records a canceled run or attempt outcome.
- Tests cover legal and illegal command transitions and the resulting durable state.

#### Dependencies

- `ST-MVP-006`

#### Out Of Scope

- Keyboard bindings.
- Multi-run or child-run coordination.
