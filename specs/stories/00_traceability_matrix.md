# Jidoka Story Traceability Matrix

| Story ID | Title | Plan Sections | Phase | Depends On |
| --- | --- | --- | --- | --- |
| ST-MVP-001 | Define durable core structs and lifecycle enums | Durable Data Model; Design Rules | Phase 1 | None |
| ST-MVP-002 | Add persistence boundary and ordered event log | Persistence And Snapshots; Durable Data Model | Phase 1 | ST-MVP-001 |
| ST-MVP-003 | Boot SessionServer and public session lifecycle | Runtime Topology; Command Flow | Phase 1 | ST-MVP-001, ST-MVP-002 |
| ST-MVP-004 | Submit coding runs and allocate isolated environment leases | MVP; Environment Model; Coding Pack Boundary | Phase 1 | ST-MVP-003 |
| ST-MVP-005 | Add execution adapter boundary and attempt worker streaming | Execution Boundary; Runtime Topology; Command Flow | Phase 1 | ST-MVP-004 |
| ST-MVP-006 | Add verifier pipeline and verification results | Verification And Approval; MVP | Phase 1 | ST-MVP-005 |
| ST-MVP-007 | Support operator actions approve, retry, reject, and cancel | Verification And Approval; Command Flow | Phase 1 | ST-MVP-006 |
| ST-MVP-008 | Create TUI shell and session attachment flow | TUI Requirements; Product Definition | Phase 2 | ST-MVP-003, ST-MVP-007 |
| ST-MVP-009 | Add focused run view and live event pane | TUI Requirements; Command Flow | Phase 2 | ST-MVP-008, ST-MVP-005 |
| ST-MVP-010 | Add artifact inspection and status line | TUI Requirements; Verification And Approval | Phase 2 | ST-MVP-009, ST-MVP-006 |
| ST-MVP-011 | Wire TUI controls for interrupt, approve, retry, reject, cancel, and reconnect | TUI Requirements; Verification And Approval | Phase 2 | ST-MVP-010, ST-MVP-007 |
| ST-MVP-012 | Add fixture corpus and end-to-end MVP evaluation | Evaluation; Roadmap Phase 3 | Phase 3 | ST-MVP-007 |
| ST-MVP-013 | Harden resume, cleanup, and artifact retention | Persistence And Snapshots; Environment Model; Roadmap Phase 3 | Phase 3 | ST-MVP-012 |
| ST-EXP-001 | Prepare child-run-ready data surfaces without enabling delegation | Expansion Path; Design Rules | Phase 4 | ST-MVP-013 |
| ST-EXP-002 | Support multi-run session navigation in the TUI without multi-agent execution | Expansion Path; TUI Requirements | Phase 4 | ST-MVP-011, ST-EXP-001 |
