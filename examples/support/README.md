# Moto Support Example

This example is for teasing apart the current Moto boundary between chat agents
and workflows.

It intentionally keeps both surfaces visible:

- a front-door support chat agent with a team of specialist subagents
- explicit workflows for fixed support processes

The current example does **not** pretend that workflows are embedded inside the
agent runtime. Instead it shows the honest shape Moto has today:

- chat agent owns open-ended intake and delegation
- workflows own deterministic support processes
- workflows can reuse a specialist agent as one bounded step
- guardrails own hard safety boundaries before the agent calls a model or
  specialist

## Team

The front-door `support_router_agent` can delegate to:

- `billing_specialist`
- `operations_specialist`
- `writer_specialist`

It also installs the `support_sensitive_data` input guardrail. Requests that try
to reveal payment credentials, secrets, or bypass verification are rejected
before the LLM or any specialist subagent is called.

## Workflows

- `refund_review`
  - tool-only
  - loads customer + order data
  - applies deterministic refund policy
  - returns a structured decision

- `escalation_draft`
  - deterministic process
  - classifies severity and queue
  - uses `writer_specialist` as a bounded drafting step
  - returns a structured escalation package

## Run It

Dry-run:

```bash
mix moto support --log-level trace --dry-run
```

Chat path:

```bash
mix moto support -- "Customer says order ord_damaged arrived broken and wants a refund."
```

Workflow path:

```bash
mix moto support -- "/refund acct_vip ord_damaged Damaged on arrival"
mix moto support -- "/escalate acct_trial Customer is locked out and threatening to cancel"
```
