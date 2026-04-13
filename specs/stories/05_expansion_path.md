# Expansion Stories

### ST-EXP-001 Prepare child-run-ready data surfaces without enabling delegation

#### Goal

Leave the MVP data model ready for later child-run support without introducing delegation behavior now.

#### Scope

- Preserve optional `parent_run_id` and `role` fields in durable shapes where useful.
- Make snapshots and event naming tolerant of more than one run in a session.
- Keep the implementation behavior single-run from an execution perspective.

#### Acceptance Criteria

- Durable run or event shapes can represent optional parent-run lineage and role metadata without breaking existing MVP flows.
- Session snapshots can enumerate more than one run even though the runtime still executes one run at a time in the MVP.
- Existing MVP APIs and tests remain backward compatible.
- No delegation commands, run-graph machinery, merge logic, or child-run supervisors are introduced.
- Tests cover the optional lineage fields and the multi-run snapshot shape without enabling child-run execution.

#### Dependencies

- `ST-MVP-013`

#### Out Of Scope

- Delegation.
- Merge decisions.
- Parallel runs.

### ST-EXP-002 Support multi-run session navigation in the TUI without multi-agent execution

#### Goal

Let the TUI browse and switch among multiple runs in a session before any real multi-agent execution work begins.

#### Scope

- Add session-level run navigation in the TUI.
- Make the focused run view switchable.
- Keep execution semantics single-run.

#### Acceptance Criteria

- The TUI can list available runs within a session and switch focus among them.
- Run navigation does not require or imply child-run delegation behavior.
- The focused artifact, status, and event panes update correctly when the selected run changes.
- Reconnect preserves the currently selected run when practical or restores a sensible default when not.
- Tests or scripted UI coverage verify run switching and focused-pane updates.

#### Dependencies

- `ST-MVP-011`
- `ST-EXP-001`

#### Out Of Scope

- Delegated child runs.
- Merge reviews.
- Coordination topologies.
