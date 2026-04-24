# Bagu Consumer

Small local integration harness for `bagu` + `ash_jido` + Phoenix LiveView.

This consumer app exists to validate real Ash resource integration behavior
without coupling those checks to Bagu's unit tests.

It currently verifies:

- AshJido actor passthrough from `scope` when `actor` is omitted
- authorization failure when neither `actor` nor `scope.actor` is present
- Bagu's current `ash_resource` behavior: no default actor is supplied, and
  `Bagu.Agent` requires an explicit `context.actor`
- Phoenix LiveView integration with a thread-backed Bagu agent view projection

## Phoenix LiveView Spike

The root LiveView demonstrates the proposed Bagu/Phoenix boundary:

- `BaguConsumerWeb.SupportChatView` starts/reuses a Bagu agent and defines the
  UI-facing projection hooks.
- `Bagu.Agent.View` projects the canonical `Jido.Thread` into separate
  `visible_messages`, `llm_context`, and debug `events`.
- `BaguConsumerWeb.SupportChatLive` renders those projections without treating
  the visible transcript as the provider-facing LLM context.

Run the Phoenix server:

```bash
mix deps.get
mix phx.server
```

Then open http://localhost:4002.

## Run

```bash
cd dev/bagu_consumer
mix setup
mix test
```
