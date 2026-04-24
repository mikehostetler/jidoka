# Errors And Debugging

Jidoka public runtime APIs return structured success, interrupt, handoff, or error
shapes. Use that structure at application boundaries.

## Public Return Shapes

`Jidoka.chat/3` and generated agent `chat/3` return:

```elixir
{:ok, value}
{:interrupt, %Jidoka.Interrupt{}}
{:handoff, %Jidoka.Handoff{}}
{:error, %Jidoka.Error.ValidationError{}}
{:error, %Jidoka.Error.ConfigError{}}
{:error, %Jidoka.Error.ExecutionError{}}
```

Workflow runs return:

```elixir
{:ok, output}
{:error, %Jidoka.Error.ValidationError{}}
{:error, %Jidoka.Error.ConfigError{}}
{:error, %Jidoka.Error.ExecutionError{}}
```

## Formatting Errors

Format errors for users with `Jidoka.format_error/1`:

```elixir
case Jidoka.chat(pid, "Hello") do
  {:ok, reply} ->
    reply

  {:error, reason} ->
    Logger.warning(Jidoka.format_error(reason))
end
```

Unknown terms still format with `inspect/1`, but known public runtime
boundaries normalize failures into Jidoka errors.

## Error Classes

Validation errors mean the caller supplied invalid runtime input:

```elixir
{:error, reason} = Jidoka.chat(pid, "Hello", context: "acct_123")
Jidoka.format_error(reason)
#=> "Invalid context: pass `context:` as a map or keyword list."
```

Config errors mean the runtime target or module configuration is invalid:

```elixir
{:error, reason} = Jidoka.inspect_workflow(NotAWorkflow)
Jidoka.format_error(reason)
#=> "Module is not a Jidoka workflow."
```

Execution errors mean configured work failed:

```elixir
{:error, reason} = Jidoka.Workflow.run(MyApp.Workflows.FailingWorkflow, %{})
Jidoka.format_error(reason)
#=> "Workflow execution failed."
```

Low-level causes are preserved in `reason.details.cause`.

## Inspect Agents

Use `Jidoka.inspect_agent/1` for compiled agents, imported agents, and running
servers:

```elixir
{:ok, definition} = Jidoka.inspect_agent(MyApp.SupportAgent)
{:ok, imported_definition} = Jidoka.inspect_agent(imported_agent)
{:ok, running} = Jidoka.inspect_agent(pid)
```

Compiled definition maps include stable fields such as:

- `:kind`
- `:id`
- `:description`
- `:model`
- `:context`
- `:tool_names`
- `:subagent_names`
- `:workflow_names`
- `:handoff_names`
- `:memory`
- `:hooks`
- `:guardrails`

Do not use internal generated helpers as the public inspection API.

## Inspect Requests

Use `Jidoka.inspect_request/1` after a turn:

```elixir
{:ok, summary} = Jidoka.inspect_request(pid)
```

Or inspect a specific request id:

```elixir
{:ok, summary} = Jidoka.inspect_request(pid, "req-123")
```

Request summaries can include recent tool, subagent, workflow, handoff,
guardrail, hook, and memory metadata when those features were involved.

## Inspect Workflows

Use `Jidoka.inspect_workflow/1` to inspect a compiled workflow definition:

```elixir
{:ok, workflow} = Jidoka.inspect_workflow(MyApp.Workflows.RefundReview)
```

Stable fields include:

- `:kind`
- `:id`
- `:module`
- `:description`
- `:input_schema`
- `:steps`
- `:dependencies`
- `:output`

Raw Runic graph structures are intentionally not part of the stable public
inspection shape.

## Debug Runs

Some APIs support debug return values. Workflows can return debug output:

```elixir
{:ok, debug} =
  Jidoka.Workflow.run(MyApp.Workflows.RefundReview, input, return: :debug)
```

Workflow capabilities and subagents can expose bounded metadata with
`result: :structured`.

Use debug metadata for observability and tests. Avoid requiring production
callers to pattern-match on internal causes unless the application owns that
specific boundary.

## CLI Error Display

Demo CLIs print errors through `Jidoka.format_error/1`. Follow that pattern in
your own Mix tasks:

```elixir
case MyApp.SupportAgent.chat(pid, prompt) do
  {:ok, reply} -> IO.puts(reply)
  {:handoff, handoff} -> IO.inspect(handoff)
  {:interrupt, interrupt} -> IO.inspect(interrupt)
  {:error, reason} -> IO.puts("error> #{Jidoka.format_error(reason)}")
end
```
