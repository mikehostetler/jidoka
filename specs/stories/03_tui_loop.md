# TUI Stories

### ST-MVP-008 Create TUI shell and session attachment flow

#### Goal

Provide the first usable terminal surface for the MVP by attaching to a session and rendering a stable shell.

#### Scope

- Boot the TUI application shell.
- Connect the TUI to an existing or newly opened session.
- Subscribe to runtime updates through snapshots and events.

#### Acceptance Criteria

- The TUI can attach to a current or selected session and fetch an initial snapshot.
- The TUI subscribes to session events and updates its local view model without owning durable state.
- The shell renders stable top-level regions for status, activity, and operator input.
- Missing, closed, or disconnected sessions are handled with an explicit recoverable UI state.
- Tests or smoke coverage exercise the session attachment path and initial render model.

#### Dependencies

- `ST-MVP-003`
- `ST-MVP-007`

#### Out Of Scope

- Artifact browsing details.
- Approval keyboard shortcuts.

### ST-MVP-009 Add focused run view and live event pane

#### Goal

Make attempt progress legible in the terminal while work is running.

#### Scope

- Add a focused run view.
- Add a live transcript or event pane.
- Render incremental updates without terminal thrash.

#### Acceptance Criteria

- The TUI shows the current run, the latest attempt, and recent progress in a dedicated focused view.
- Runtime events are rendered as an event stream or transcript pane suitable for a long-running coding task.
- Updates are batched or throttled enough to avoid visibly unstable rendering during streaming output.
- The TUI reads from snapshots and events rather than reaching into runtime internals.
- Tests or controller-level coverage verify that event updates drive the expected view-model changes.

#### Dependencies

- `ST-MVP-008`
- `ST-MVP-005`

#### Out Of Scope

- Artifact detail panes.
- Operator action bindings beyond passive viewing.

### ST-MVP-010 Add artifact inspection and status line

#### Goal

Give the operator the context needed to make an approval decision without leaving the TUI.

#### Scope

- Add artifact browsing for diff, logs, and verifier output.
- Add a compact status line that reflects the current session, run, attempt, and lease.

#### Acceptance Criteria

- The TUI exposes a way to inspect diff, log, and verifier-report artifacts for the focused run.
- The UI includes a status line or equivalent summary showing session status, run status, attempt status, and environment lease identity.
- Artifact browsing is resilient when a given artifact type is absent.
- The verifier result is visible in the TUI without requiring external inspection.
- Tests or view-model coverage verify artifact summaries and status-line formatting.

#### Dependencies

- `ST-MVP-009`
- `ST-MVP-006`

#### Out Of Scope

- Retry or approval controls.
- Multi-run navigation.

### ST-MVP-011 Wire TUI controls for interrupt, approve, retry, reject, cancel, and reconnect

#### Goal

Turn the TUI from a passive display into the primary control surface for the MVP loop.

#### Scope

- Add operator controls for the supported runtime commands.
- Support reconnecting to in-progress sessions after restart.
- Route commands through the public runtime surface.

#### Acceptance Criteria

- The TUI can issue interrupt or steer, approve, retry, reject, and cancel actions through runtime commands rather than internal process calls.
- The operator can reconnect to a previously running session and continue interacting with it.
- Control-state presentation reflects when a command is legal or illegal for the focused run.
- Command failures are surfaced clearly in the UI instead of being dropped.
- Tests or scripted UI/controller coverage exercise reconnect flow and at least one successful operator action for each command family.

#### Dependencies

- `ST-MVP-010`
- `ST-MVP-007`

#### Out Of Scope

- Child-run navigation.
- Merge or handoff workflows.
