# Jidoka

Jidoka is a headless coding-session runtime with a small public facade.

`Jidoka.Agent` is the primary public API.
`Jidoka` only exposes session lifecycle helpers.

## Example

```elixir
{:ok, session_ref} = Jidoka.start_session(id: "repo-main", cwd: "/path/to/repo")

{:ok, request} = Jidoka.Agent.ask(session_ref, "inspect the failing tests")
{:ok, _result} = Jidoka.Agent.await(session_ref, request.id)

{:ok, branch_id} = Jidoka.Agent.branch(session_ref, label: "before-refactor")
{:ok, snapshot} = Jidoka.Agent.navigate(session_ref, branch_id)

{:ok, latest} = Jidoka.Agent.snapshot(session_ref)
:ok = Jidoka.close_session(session_ref)
```

## IEx

For the first interactive shell, use `iex -S mix` and the thin helper module:

```elixir
iex -S mix

{:ok, ref} = Jidoka.IEx.open(id: "repo-main", cwd: File.cwd!())
{:ok, sub} = Jidoka.IEx.watch(ref)
{:ok, req} = Jidoka.IEx.ask(ref, "inspect the failing tests")
{:ok, snap} = Jidoka.IEx.snapshot(ref)
flush()
:ok = Jidoka.IEx.unwatch(sub)
```

## Design Notes

- external commands are normalized into canonical signals
- the runtime emits signals and keeps a stable snapshot API for adapters
- `Jido.Thread` is the audit log conceptually, while authoritative state is runtime metadata plus durable history
