defmodule JidokaConsumerWeb.SupportChatLive do
  use JidokaConsumerWeb, :live_view

  alias JidokaConsumerWeb.SupportChatView

  @impl true
  def mount(_params, session, socket) do
    {:ok, pid} = SupportChatView.start_agent(session)
    {:ok, view} = SupportChatView.snapshot(pid, session)

    {:ok,
     socket
     |> assign(:agent_pid, pid)
     |> assign(:session, session)
     |> assign(:view, view)
     |> assign(:message, "")}
  end

  @impl true
  def handle_event("change_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :message, message)}
  end

  def handle_event("send", %{"message" => message}, socket) do
    view = SupportChatView.before_submit(socket.assigns.view, message)
    socket = assign(socket, view: view, message: "")

    result =
      SupportChatView.send_message(socket.assigns.agent_pid, message, socket.assigns.session)

    view =
      case SupportChatView.after_result(socket.assigns.agent_pid, socket.assigns.session, result) do
        {:ok, updated_view} -> updated_view
        {:error, reason} -> %{view | status: :error, error: Jidoka.format_error(reason)}
      end

    {:noreply, assign(socket, :view, view)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <script src="https://cdn.tailwindcss.com">
    </script>
    <style>
      html, body { background: #f8fafc; color: #0f172a; }
    </style>

    <main class="min-h-screen bg-slate-50 text-slate-950 antialiased">
      <div class="mx-auto flex min-h-screen w-full max-w-7xl flex-col px-4 py-5 sm:px-6 lg:px-8">
        <header class="mb-5 flex flex-col gap-4 border-b border-slate-200 pb-5 lg:flex-row lg:items-end lg:justify-between">
          <div class="space-y-3">
            <div class="flex items-center gap-3">
              <div class="grid h-10 w-10 place-items-center rounded-lg bg-slate-950 text-sm font-semibold text-white shadow-sm">
                B
              </div>
              <div>
                <p class="text-xs font-medium uppercase tracking-wide text-slate-500">
                  Phoenix LiveView
                </p>
                <h1 class="text-2xl font-semibold text-slate-950">Jidoka Support Agent</h1>
              </div>
            </div>
            <p class="max-w-2xl text-sm leading-6 text-slate-600">
              A support console backed by a running Jidoka agent, with chat output and runtime
              projections kept separate.
            </p>
          </div>

          <dl class="grid grid-cols-1 gap-2 text-sm sm:grid-cols-3 lg:min-w-[520px]">
            <div class="rounded-lg border border-slate-200 bg-white px-3 py-2 shadow-sm">
              <dt class="text-xs font-medium uppercase text-slate-500">Agent</dt>
              <dd class="mt-1 truncate font-mono text-xs text-slate-800">{@view.agent_id}</dd>
            </div>
            <div class="rounded-lg border border-slate-200 bg-white px-3 py-2 shadow-sm">
              <dt class="text-xs font-medium uppercase text-slate-500">Conversation</dt>
              <dd class="mt-1 truncate font-mono text-xs text-slate-800">{@view.conversation_id}</dd>
            </div>
            <div class="rounded-lg border border-slate-200 bg-white px-3 py-2 shadow-sm">
              <dt class="text-xs font-medium uppercase text-slate-500">Status</dt>
              <dd class="mt-1">
                <span class={[
                  "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium ring-1 ring-inset",
                  status_badge_class(@view.status)
                ]}>
                  {@view.status}
                </span>
              </dd>
            </div>
          </dl>
        </header>

        <div class="grid flex-1 gap-5 lg:grid-cols-[minmax(0,1fr)_420px]">
          <section class="flex min-h-[680px] flex-col overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
            <div class="border-b border-slate-200 px-5 py-4">
              <h2 class="text-base font-semibold text-slate-950">Visible Messages</h2>
              <p class="mt-1 text-sm text-slate-600">User-facing transcript rendered from the agent view.</p>
            </div>

            <div id="visible-messages" class="flex-1 space-y-4 overflow-y-auto px-5 py-5">
              <div
                :if={@view.visible_messages == []}
                class="flex h-full min-h-[360px] items-center justify-center rounded-lg border border-dashed border-slate-300 bg-slate-50 px-6 text-center"
              >
                <div class="max-w-[240px]">
                  <p class="text-sm font-medium text-slate-800">No messages yet</p>
                  <p class="mt-1 text-sm leading-6 text-slate-500">
                    Send a support request to start the conversation.
                  </p>
                </div>
              </div>

              <article
                :for={message <- @view.visible_messages}
                class={["flex", message_row_class(message.role)]}
              >
                <div class={[
                  "max-w-[82%] rounded-lg px-4 py-3 shadow-sm ring-1 ring-inset",
                  message_bubble_class(message.role)
                ]}>
                  <div class="mb-1 flex items-center gap-2">
                    <span class={[
                      "rounded-full px-2 py-0.5 text-[11px] font-medium uppercase",
                      message_role_class(message.role)
                    ]}>
                      {role_label(message.role)}
                    </span>
                    <span :if={Map.get(message, :pending?)} class="text-xs text-slate-400">
                      pending
                    </span>
                  </div>
                  <p class="whitespace-pre-wrap text-sm leading-6">{message.content}</p>
                </div>
              </article>
            </div>

            <form class="border-t border-slate-200 bg-slate-50 p-4" phx-change="change_message" phx-submit="send">
              <label for="message" class="sr-only">Message</label>
              <div class="flex flex-col gap-3 sm:flex-row sm:items-end">
                <textarea
                  id="message"
                  name="message"
                  rows="3"
                  class="min-h-[92px] flex-1 resize-y rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm leading-6 text-slate-950 shadow-sm outline-none transition placeholder:text-slate-400 focus:border-sky-500 focus:ring-4 focus:ring-sky-100"
                  placeholder="Ask the support note agent..."
                >{@message}</textarea>
                <button
                  type="submit"
                  class="inline-flex h-10 items-center justify-center rounded-lg bg-slate-950 px-4 text-sm font-medium text-white shadow-sm transition hover:bg-slate-800 focus:outline-none focus:ring-4 focus:ring-slate-200 disabled:cursor-not-allowed disabled:bg-slate-400"
                  phx-disable-with="Sending..."
                >
                  Send
                </button>
              </div>
            </form>
          </section>

          <aside class="space-y-4">
            <p
              :if={@view.error}
              class="rounded-lg border border-rose-200 bg-rose-50 px-4 py-3 text-sm leading-6 text-rose-800 shadow-sm"
            >
              {@view.error}
            </p>

            <section class="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
              <div class="border-b border-slate-200 px-4 py-3">
                <h2 class="text-sm font-semibold text-slate-950">LLM Context</h2>
                <p class="mt-1 text-xs leading-5 text-slate-500">Provider-facing thread projection.</p>
              </div>
              <ol id="llm-context" class="max-h-72 space-y-3 overflow-y-auto p-4">
                <li :if={@view.llm_context == []} class="text-sm text-slate-500">No LLM context yet.</li>
                <li :for={message <- @view.llm_context} class="rounded-lg bg-slate-50 p-3 ring-1 ring-slate-200">
                  <code class="text-xs font-semibold text-slate-700">
                    {message.seq}: {message.role}
                  </code>
                  <pre class="mt-2 overflow-x-auto whitespace-pre-wrap text-xs leading-5 text-slate-600">{inspect(message, pretty: true)}</pre>
                </li>
              </ol>
            </section>

            <section class="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
              <div class="border-b border-slate-200 px-4 py-3">
                <h2 class="text-sm font-semibold text-slate-950">Debug Events</h2>
                <p class="mt-1 text-xs leading-5 text-slate-500">Tool calls, tool results, and context operations.</p>
              </div>
              <ol id="debug-events" class="max-h-72 space-y-3 overflow-y-auto p-4">
                <li :if={@view.events == []} class="text-sm text-slate-500">No debug events yet.</li>
                <li :for={event <- @view.events} class="rounded-lg bg-slate-50 p-3 ring-1 ring-slate-200">
                  <code class="text-xs font-semibold text-slate-700">
                    {event.seq}: {event.label}
                  </code>
                  <pre class="mt-2 overflow-x-auto whitespace-pre-wrap text-xs leading-5 text-slate-600">{inspect(event.payload, pretty: true)}</pre>
                </li>
              </ol>
            </section>

            <section class="overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm">
              <div class="border-b border-slate-200 px-4 py-3">
                <h2 class="text-sm font-semibold text-slate-950">Runtime Context</h2>
              </div>
              <pre class="overflow-x-auto p-4 text-xs leading-5 text-slate-600">{inspect(@view.runtime_context, pretty: true)}</pre>
            </section>
          </aside>
        </div>
      </div>
    </main>
    """
  end

  defp status_badge_class(:idle), do: "bg-emerald-50 text-emerald-700 ring-emerald-200"
  defp status_badge_class(:running), do: "bg-amber-50 text-amber-700 ring-amber-200"
  defp status_badge_class(:error), do: "bg-rose-50 text-rose-700 ring-rose-200"
  defp status_badge_class(:interrupted), do: "bg-violet-50 text-violet-700 ring-violet-200"
  defp status_badge_class(:handoff), do: "bg-sky-50 text-sky-700 ring-sky-200"
  defp status_badge_class(_status), do: "bg-slate-100 text-slate-700 ring-slate-200"

  defp message_row_class(:user), do: "justify-end"
  defp message_row_class(_role), do: "justify-start"

  defp message_bubble_class(:user), do: "bg-slate-950 text-white ring-slate-950"
  defp message_bubble_class(:assistant), do: "bg-white text-slate-900 ring-slate-200"
  defp message_bubble_class(_role), do: "bg-slate-50 text-slate-900 ring-slate-200"

  defp message_role_class(:user), do: "bg-white/10 text-white"
  defp message_role_class(:assistant), do: "bg-sky-50 text-sky-700"
  defp message_role_class(_role), do: "bg-slate-200 text-slate-700"

  defp role_label(role) do
    role
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
