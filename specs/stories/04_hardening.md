# Hardening Stories

### ST-MVP-012 Add fixture corpus and end-to-end MVP evaluation

#### Goal

Create a small but real evaluation harness that proves the MVP loop works across the core success and failure cases.

#### Scope

- Add a fixture corpus for coding-task scenarios.
- Add an end-to-end harness that runs through the public runtime surface.
- Capture durable artifacts and verification results for analysis.

#### Acceptance Criteria

- The repository contains a small fixture corpus with at least a passing task, a retryable verifier failure, and a resume-oriented scenario.
- The evaluation harness drives the runtime through public APIs rather than private internal shortcuts.
- Evaluation output captures final outcome, attempt count, verification result, and artifact references or summaries.
- Running the harness is documented and repeatable in local development.
- Tests or fixture assertions verify that the expected scenarios complete with the correct classification.

#### Dependencies

- `ST-MVP-007`

#### Out Of Scope

- Large-scale benchmark automation.
- Multi-agent evaluation.

### ST-MVP-013 Harden resume, cleanup, and artifact retention

#### Goal

Make the MVP robust enough to survive interruption and leave behind predictable workspace state.

#### Scope

- Strengthen session and attempt resume behavior.
- Define and implement isolated environment cleanup policy.
- Define and enforce artifact retention behavior for core artifact types.

#### Acceptance Criteria

- An interrupted session can be resumed without corrupting durable run or attempt state.
- The runtime has explicit behavior for orphaned isolated workspaces: reattach, clean up, or mark for operator review.
- Artifact retention for diff, logs, transcript, and verifier output is documented and enforced by code where appropriate.
- Cleanup behavior is testable and does not silently delete state needed for resume.
- Tests cover at least one interrupted attempt scenario and one cleanup or reattach scenario.

#### Dependencies

- `ST-MVP-012`

#### Out Of Scope

- Child-run recovery.
- Alternate persistence backends beyond what the MVP already uses.
