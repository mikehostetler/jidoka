# Imported Agents

Imported agents let applications load a constrained JSON/YAML representation of
the Jidoka agent shape at runtime.

They are intentionally not raw Elixir module loading. Every executable feature
must resolve through an explicit `available_*` registry supplied by the
application.

## Spec Shape

Imported specs mirror the beta DSL sections:

```json
{
  "agent": {
    "id": "sample_math_agent",
    "description": "Imported math assistant",
    "context": {
      "tenant": "demo",
      "channel": "json"
    }
  },
  "defaults": {
    "model": "fast",
    "instructions": "You are a concise assistant."
  },
  "capabilities": {
    "tools": ["add_numbers"],
    "skills": ["math-discipline"],
    "skill_paths": ["../skills"],
    "web": ["search"],
    "plugins": ["math_plugin"]
  },
  "lifecycle": {
    "hooks": {
      "before_turn": ["reply_with_final_answer"]
    },
    "guardrails": {
      "input": ["block_secret_prompt"]
    }
  }
}
```

Top-level flat specs are rejected. Keep the section layout.

## Import From JSON Or YAML

```elixir
{:ok, agent} =
  Jidoka.import_agent(json,
    available_tools: [MyApp.Tools.AddNumbers],
    available_plugins: [MyApp.Plugins.Math],
    available_hooks: [MyApp.Hooks.ReplyWithFinalAnswer],
    available_guardrails: [MyApp.Guardrails.BlockSecretPrompt]
  )

{:ok, pid} = Jidoka.start_agent(agent, id: "json-agent")
{:ok, reply} = Jidoka.chat(pid, "Use add_numbers to add 2 and 3.")
```

Import from a file:

```elixir
{:ok, agent} =
  Jidoka.import_agent_file("priv/agents/support_router.json",
    available_tools: [MyApp.Tools.LookupOrder]
  )
```

Encode back to JSON/YAML:

```elixir
{:ok, json} = Jidoka.encode_agent(agent, format: :json)
{:ok, yaml} = Jidoka.encode_agent(agent, format: :yaml)
```

## Registries

Imported capabilities resolve by published names:

```elixir
Jidoka.import_agent(json,
  available_tools: [MyApp.Tools.AddNumbers],
  available_plugins: [MyApp.Plugins.Math],
  available_subagents: [MyApp.ResearchAgent],
  available_workflows: [MyApp.Workflows.RefundReview],
  available_handoffs: [MyApp.BillingAgent],
  available_hooks: [MyApp.Hooks.ReplyWithFinalAnswer],
  available_guardrails: [MyApp.Guardrails.SafePrompt],
  available_characters: %{"support_advisor" => MyApp.Characters.SupportAdvisor}
)
```

Most registries accept either a list of modules or a map of published name to
module. Raw module strings in JSON/YAML are rejected because they bypass the
application allowlist.

The built-in `web` capability is the exception: it uses fixed Jidoka modes
(`"search"` and `"read_only"`) and does not require an `available_*` registry.

## Context

Imported agents support default context only:

```json
{
  "agent": {
    "id": "imported_support_agent",
    "context": {
      "tenant": "demo",
      "channel": "support"
    }
  }
}
```

Per-turn context merges over those defaults:

```elixir
Jidoka.chat(pid, "Help with this account.",
  context: %{tenant: "acme", account_id: "acct_123"}
)
```

Imported specs do not support portable Zoi schemas yet. Use compiled agents when
you need compile-time schema validation.

## Subagents

Imported subagents are resolved through `available_subagents`:

```json
{
  "capabilities": {
    "subagents": [
      {
        "agent": "research_agent",
        "as": "research_agent",
        "description": "Ask the research specialist for concise notes",
        "target": "ephemeral",
        "timeout_ms": 30000,
        "forward_context": {"mode": "only", "keys": ["tenant", "session"]},
        "result": "structured"
      }
    ]
  }
}
```

Use `Jidoka.ImportedAgent.Subagent` when an Elixir manager agent needs to delegate
to a JSON/YAML-authored specialist.

## Workflows

Imported workflow capabilities resolve through `available_workflows`:

```json
{
  "capabilities": {
    "workflows": [
      {
        "workflow": "refund_review",
        "as": "review_refund",
        "description": "Review refund eligibility.",
        "timeout": 30000,
        "forward_context": {"mode": "only", "keys": ["tenant", "session"]},
        "result": "structured"
      }
    ]
  }
}
```

The spec references the workflow's published id, not an Elixir module string.

## Web Access

Imported specs can opt into Jidoka's built-in low-risk web modes:

```json
{
  "capabilities": {
    "web": [
      {"mode": "read_only"}
    ]
  }
}
```

`"search"` exposes `search_web`. `"read_only"` exposes `search_web`,
`read_page`, and `snapshot_url`. Imported web capabilities do not accept raw
module strings or arbitrary browser action configuration.

## Handoffs

Imported handoffs resolve through `available_handoffs`:

```json
{
  "capabilities": {
    "handoffs": [
      {
        "agent": "billing_specialist",
        "as": "transfer_billing_ownership",
        "description": "Transfer ongoing billing ownership.",
        "target": "auto",
        "forward_context": {"mode": "only", "keys": ["tenant", "account_id"]}
      }
    ]
  }
}
```

`target: "auto"` starts or reuses a deterministic target for the current
conversation. `"peer"` targets require `peer_id` or `peer_id_context_key`.

## Memory

Imported memory uses the constrained lifecycle format:

```json
{
  "lifecycle": {
    "memory": {
      "mode": "conversation",
      "namespace": "context",
      "context_namespace_key": "session",
      "capture": "conversation",
      "retrieve": {"limit": 4},
      "inject": "instructions"
    }
  }
}
```

This mirrors the compiled DSL's supported memory subset.

## Parity Rule

Imported agents are first-class Jidoka agents. When a Jidoka feature has a safe
portable representation, the imported format should support it. When a feature
cannot be represented safely, prefer an explicit registry or document the gap.
