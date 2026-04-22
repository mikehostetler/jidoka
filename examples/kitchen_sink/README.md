# Moto Kitchen Sink Example

This example exists to show every major Moto feature in one place.

Do not start here if you are learning Moto. Start with `examples/chat` or
`examples/orchestrator` first. This folder is a showcase and integration surface,
not the recommended shape for a normal application agent.

It demonstrates:

- `agent do schema ... end`
- dynamic `instructions`
- direct tools
- Ash resource tool expansion
- Jido.AI skills loaded from `SKILL.md`
- configured MCP tool sync
- Moto plugins
- `before_turn`, `after_turn`, and `on_interrupt` hooks
- input, output, and tool guardrails
- conversation memory
- compiled subagents
- imported JSON subagents
- debug and inspection output through `mix moto`

Run the dry-run view:

```bash
mix moto kitchen_sink --log-level trace --dry-run
```

Run a one-shot prompt:

```bash
mix moto kitchen_sink --log-level debug -- "Use the research_agent specialist to explain embeddings"
```

The MCP portion expects the configured `:local_fs` endpoint. The dry-run command
does not start the agent or connect to MCP.
