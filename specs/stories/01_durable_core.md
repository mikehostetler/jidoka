# Durable Core Stories

### ST-MVP-001 Define durable core structs and lifecycle enums

#### Goal

Establish the smallest typed durable model required by the MVP so later runtime work has stable contracts.

#### Scope

- Introduce first-class modules for `Session`, `Run`, `Attempt`, `Artifact`, `EnvironmentLease`, `VerificationResult`, `Outcome`, and `Event`.
- Define the status and outcome vocabulary used by the MVP.
- Document the relationship between session, run, and attempt in code-facing docs or module docs.

#### Acceptance Criteria

- The runtime has named modules for all MVP durable entities listed above.
- Each durable entity carries a stable `id`, a `version`, explicit timestamps, and an explicit status or outcome field where applicable.
- `Run` may reserve optional future-facing fields such as `parent_run_id` and `role`, but no child-run behavior is implemented.
- The status vocabulary is explicit and shared rather than open-ended stringly typed state.
- Tests cover construction or validation of each durable entity and the allowed lifecycle values.

#### Dependencies

- None.

#### Out Of Scope

- Persistence adapters.
- Supervisors or GenServer ownership.
- TUI rendering.

### ST-MVP-002 Add persistence boundary and ordered event log

#### Goal

Define how durable runtime state is stored and replayed before higher-level runtime behavior is added.

#### Scope

- Introduce the persistence interface used by the MVP runtime.
- Add an in-memory adapter that can store and load enough durable state to reconstruct a session.
- Add append-only typed event or transition recording with stable per-session ordering.

#### Acceptance Criteria

- The runtime has a clear persistence boundary for sessions, runs, attempts, leases, artifacts, verification results, outcomes, and events or equivalent transition records.
- The in-memory adapter can round-trip a populated session envelope without relying on live pids.
- Event append order is stable and testable within a session.
- Snapshots are not the source of truth and can be rebuilt from persisted data.
- Tests cover round-trip load and save, ordered event append behavior, and resume-friendly reconstruction.

#### Dependencies

- `ST-MVP-001`

#### Out Of Scope

- Execution kernel integration.
- Environment creation.
- TUI subscriptions.

### ST-MVP-003 Boot SessionServer and public session lifecycle

#### Goal

Create the first OTP backbone for the MVP with one process that clearly owns durable runtime writes.

#### Scope

- Add the application supervision tree needed for sessions and attempts.
- Introduce `Jidoka.SessionServer` as the single durable writer for MVP state.
- Expose the public session lifecycle API needed to open, resume, and inspect a session.

#### Acceptance Criteria

- The application boots a registry, a session supervisor, an attempt supervisor, and any event bus support process required by the MVP.
- `Jidoka.SessionServer` owns session persistence, run persistence, attempt persistence, lease persistence, and snapshot generation.
- Public session lifecycle calls exist for opening a session, resuming a session, and reading session or run snapshots.
- Resuming a persisted session rebuilds process state without changing durable identifiers.
- Tests cover session boot, resume from persisted data, and snapshot availability after restore.

#### Dependencies

- `ST-MVP-001`
- `ST-MVP-002`

#### Out Of Scope

- Running a coding task.
- Verifier logic.
- Terminal UI.
