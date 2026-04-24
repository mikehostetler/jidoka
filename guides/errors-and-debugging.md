# Errors And Debugging

Bagu public runtime APIs return structured success, interrupt, handoff, or error
shapes. Use that structure at application boundaries.

## Public Return Shapes

`Bagu.chat/3` and generated agent `chat/3` return:

```elixir
{:ok, value}
{:interrupt, %Bagu.Interrupt{}}
{:handoff, %Bagu.Handoff{}}
{:error, %Bagu.Error.ValidationError{}}
{:error, %Bagu.Error.ConfigError{}}
{:error, %Bagu.Error.ExecutionError{}}
```

Workflow runs return:

```elixir
{:ok, output}
{:error, %Bagu.Error.ValidationError{}}
{:error, %Bagu.Error.ConfigError{}}
{:error, %Bagu.Error.ExecutionError{}}
```

## Formatting Errors

Format errors for users with `Bagu.format_error/1`:

```elixir
case Bagu.chat(pid, "Hello") do
  {:ok, reply} ->
    reply

  {:error, reason} ->
    Logger.warning(Bagu.format_error(reason))
end
```

Unknown terms still format with `inspect/1`, but known public runtime
boundaries normalize failures into Bagu errors.

## Error Classes

Validation errors mean the caller supplied invalid runtime input:

```elixir
{:error, reason} = Bagu.chat(pid, "Hello", context: "acct_123")
Bagu.format_error(reason)
#=> "Invalid context: pass `context:` as a map or keyword list."
```

Config errors mean the runtime target or module configuration is invalid:

```elixir
{:error, reason} = Bagu.inspect_workflow(NotAWorkflow)
Bagu.format_error(reason)
#=> "Module is not a Bagu workflow."
```

Execution errors mean configured work failed:

```elixir
{:error, reason} = Bagu.Workflow.run(MyApp.Workflows.FailingWorkflow, %{})
Bagu.format_error(reason)
#=> "Workflow execution failed."
```

Low-level causes are preserved in `reason.details.cause`.

## Inspect Agents

Use `Bagu.inspect_agent/1` for compiled agents, imported agents, and running
servers:

```elixir
{:ok, definition} = Bagu.inspect_agent(MyApp.SupportAgent)
{:ok, imported_definition} = Bagu.inspect_agent(imported_agent)
{:ok, running} = Bagu.inspect_agent(pid)
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

Use `Bagu.inspect_request/1` after a turn:

```elixir
{:ok, summary} = Bagu.inspect_request(pid)
```

Or inspect a specific request id:

```elixir
{:ok, summary} = Bagu.inspect_request(pid, "req-123")
```

Request summaries can include recent tool, subagent, workflow, handoff,
guardrail, hook, and memory metadata when those features were involved.

## Inspect Workflows

Use `Bagu.inspect_workflow/1` to inspect a compiled workflow definition:

```elixir
{:ok, workflow} = Bagu.inspect_workflow(MyApp.Workflows.RefundReview)
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
  Bagu.Workflow.run(MyApp.Workflows.RefundReview, input, return: :debug)
```

Workflow capabilities and subagents can expose bounded metadata with
`result: :structured`.

Use debug metadata for observability and tests. Avoid requiring production
callers to pattern-match on internal causes unless the application owns that
specific boundary.

## CLI Error Display

Demo CLIs print errors through `Bagu.format_error/1`. Follow that pattern in
your own Mix tasks:

```elixir
case MyApp.SupportAgent.chat(pid, prompt) do
  {:ok, reply} -> IO.puts(reply)
  {:handoff, handoff} -> IO.inspect(handoff)
  {:interrupt, interrupt} -> IO.inspect(interrupt)
  {:error, reason} -> IO.puts("error> #{Bagu.format_error(reason)}")
end
```
