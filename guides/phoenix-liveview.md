# Phoenix LiveView

Phoenix integration should treat Jidoka as an OTP runtime plus a projection
source. The LiveView should own UI state and rendering. The agent should own
execution. `Jido.Thread` should remain the canonical event log.

The important boundary is that the provider-facing LLM context is not the same
thing as the user-visible chat transcript.

## Why The Boundary Matters

An agent turn may include:

- user messages
- assistant messages
- assistant tool-call messages
- tool result messages
- context operations
- memory injection
- guardrail and hook metadata
- debug events

Only some of that belongs in a chat UI. Tool results, context operations, and
private reasoning metadata are useful for debugging, but they should not be
rendered as normal user-facing messages.

Jidoka exposes `Jidoka.Agent.View` for this split:

```elixir
{:ok, view} = Jidoka.Agent.View.snapshot(pid)

view.visible_messages
view.llm_context
view.events
```

`visible_messages` is the transcript projection. `llm_context` is the
provider-facing message projection. `events` is a compact debug stream.

## Dev Phoenix App

The local consumer app under `dev/jidoka_consumer` contains a minimal LiveView
spike.

Run it:

```bash
cd dev/jidoka_consumer
mix deps.get
mix phx.server
```

Then open http://localhost:4002.

The root LiveView renders four panels:

- visible messages
- LLM context
- debug events
- runtime context

The source files are:

- `dev/jidoka_consumer/lib/jidoka_consumer_web/live/support_chat_live.ex`
- `dev/jidoka_consumer/lib/jidoka_consumer_web/live/support_chat_view.ex`
- `dev/jidoka_consumer/lib/jidoka_consumer/support_note_agent.ex`

## View Adapter Pattern

The spike uses a Phoenix-facing adapter module:

```elixir
defmodule MyAppWeb.SupportChatView do
  @agent MyApp.SupportAgent

  def start_agent(session) do
    agent_id = agent_id(session)

    case Jidoka.whereis(agent_id) do
      nil -> @agent.start_link(id: agent_id)
      pid -> {:ok, pid}
    end
  end

  def snapshot(pid, session) do
    with {:ok, projection} <- Jidoka.Agent.View.snapshot(pid) do
      {:ok,
       %{
         conversation_id: conversation_id(session),
         runtime_context: public_context(session),
         visible_messages: projection.visible_messages,
         llm_context: projection.llm_context,
         events: projection.events
       }}
    end
  end
end
```

This adapter is the proposed "view" concept:

- it chooses the agent
- it chooses the conversation id
- it builds runtime context
- it starts or reuses a runtime agent
- it projects the agent thread into UI data
- it defines UI hooks around submit/result behavior

The adapter should not mutate the thread directly. It should call Jidoka runtime
APIs and then re-project the agent state.

## LiveView Flow

A LiveView can follow this shape:

```elixir
def mount(_params, session, socket) do
  {:ok, pid} = MyAppWeb.SupportChatView.start_agent(session)
  {:ok, view} = MyAppWeb.SupportChatView.snapshot(pid, session)

  {:ok,
   socket
   |> assign(:agent_pid, pid)
   |> assign(:session, session)
   |> assign(:view, view)
   |> assign(:message, "")}
end

def handle_event("send", %{"message" => message}, socket) do
  view = MyAppWeb.SupportChatView.before_submit(socket.assigns.view, message)
  socket = assign(socket, view: view, message: "")

  result =
    MyAppWeb.SupportChatView.send_message(
      socket.assigns.agent_pid,
      message,
      socket.assigns.session
    )

  {:ok, view} =
    MyAppWeb.SupportChatView.after_result(
      socket.assigns.agent_pid,
      socket.assigns.session,
      result
    )

  {:noreply, assign(socket, :view, view)}
end
```

This keeps optimistic UI behavior in LiveView and canonical message history in
the agent thread.

## Runtime Context

Build runtime context from trusted session/application data:

```elixir
context = %{
  actor: current_user,
  tenant: tenant,
  channel: "phoenix_live_view",
  session: conversation_id
}

Jidoka.chat(pid, message,
  conversation: conversation_id,
  context: context
)
```

Do not let the browser provide authorization context directly. Use browser
params for message text; use server-side session data for actor, tenant, and
permission scope.

## Debugging

Use both APIs:

```elixir
Jidoka.Agent.View.snapshot(pid)
Jidoka.inspect_request(pid)
```

`Jidoka.Agent.View.snapshot/2` is for UI projection. `Jidoka.inspect_request/1` is
for request-level diagnostics such as hooks, guardrails, memory, subagents,
workflows, handoffs, usage, and errors.

## Design Direction

The likely Jidoka-level abstraction is not a Phoenix-specific component. It is a
projection/view contract:

- core: project `Jido.Thread` into stable data shapes
- app: define the agent, context, conversation id, and UI hooks
- Phoenix: render the projected data and manage optimistic/pending state

That leaves Phoenix free to use LiveView idioms while keeping Jidoka's runtime
portable to controllers, channels, jobs, tests, or non-Phoenix UIs.
