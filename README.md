# Moto

Minimal layer over Jido and Jido.AI for defining and starting chat agents.

This first implementation keeps the Spark DSL deliberately tiny.

## Setup

Set your Anthropic API key:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
```

Or copy `.env.example` to `.env` and fill in the key.

`moto` uses `dotenvy` in `config/runtime.exs` to load `.env` automatically at
runtime. Shell environment variables still win over `.env` values.

`moto` configures Jido.AI's `:fast` model alias to Anthropic Claude Haiku 4.5.
As of April 19, 2026, Anthropic lists `claude-haiku-4-5` as the current alias
and `claude-haiku-4-5-20251001` as the stable snapshot ID.

The generated runtime uses:

- `model: :fast`
- `tools: []`

The model alias itself is configured in:

- `config/config.exs` maps `:fast` to `anthropic:claude-haiku-4-5`
- `config/runtime.exs` loads `.env` and configures `:req_llm`

## Define An Agent

```elixir
defmodule MyApp.ChatAgent do
  use Moto.Agent

  agent do
    system_prompt "You are a concise assistant."
  end
end
```

The DSL currently supports exactly two options:

- `name`
- `system_prompt`

Example with both:

```elixir
defmodule MyApp.SupportAgent do
  use Moto.Agent

  agent do
    name "support"
    system_prompt "You help customers with support questions."
  end
end
```

## Start And Chat

```elixir
{:ok, pid} = MyApp.ChatAgent.start_link(id: "chat-1")
{:ok, reply} = MyApp.ChatAgent.chat(pid, "Write a one-line haiku about Elixir.")
```

Or use the shared runtime facade directly:

```elixir
{:ok, pid} = Moto.start_agent(MyApp.ChatAgent.runtime_module(), id: "chat-2")
{:ok, reply} = MyApp.ChatAgent.chat(pid, "Say hello.")
```

## Demo Script

Interactive:

```bash
mix run scripts/chat_agent.exs
```

One-shot:

```bash
mix run scripts/chat_agent.exs -- "Say hello in one sentence."
```

## Notes

- The shared runtime lives in `Moto.Runtime` and is started by `Moto.Application`.
- `Moto.Agent` uses a very small Spark DSL and generates a nested runtime module.
- The nested runtime module still uses `Jido.AI.Agent` underneath.
