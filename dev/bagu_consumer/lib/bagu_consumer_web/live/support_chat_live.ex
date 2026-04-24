defmodule BaguConsumerWeb.SupportChatLive do
  use BaguConsumerWeb, :live_view

  alias BaguConsumerWeb.SupportChatView

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
        {:error, reason} -> %{view | status: :error, error: Bagu.format_error(reason)}
      end

    {:noreply, assign(socket, :view, view)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <main class="bagu-liveview-demo">
      <section>
        <h1>Bagu Support Agent</h1>
        <p>
          This LiveView keeps the user-visible transcript separate from the LLM context projected
          from the agent thread.
        </p>
        <dl>
          <dt>Agent</dt>
          <dd>{@view.agent_id}</dd>
          <dt>Conversation</dt>
          <dd>{@view.conversation_id}</dd>
          <dt>Status</dt>
          <dd>{@view.status}</dd>
        </dl>
      </section>

      <form phx-change="change_message" phx-submit="send">
        <label for="message">Message</label>
        <textarea id="message" name="message" rows="3" placeholder="Ask the support note agent...">{@message}</textarea>
        <button type="submit">Send</button>
      </form>

      <p :if={@view.error} class="error">error: {@view.error}</p>

      <section>
        <h2>Visible Messages</h2>
        <p>These are safe to render as the chat transcript.</p>
        <div id="visible-messages">
          <p :if={@view.visible_messages == []}>No visible messages yet.</p>
          <article :for={message <- @view.visible_messages} class={"message #{message.role}"}>
            <strong>{message.role}</strong>
            <p>{message.content}</p>
          </article>
        </div>
      </section>

      <section>
        <h2>LLM Context</h2>
        <p>This projection includes provider-facing user, assistant, and tool messages.</p>
        <ol id="llm-context">
          <li :if={@view.llm_context == []}>No LLM context yet.</li>
          <li :for={message <- @view.llm_context}>
            <code>{message.seq}: {message.role}</code>
            <pre>{inspect(message, pretty: true)}</pre>
          </li>
        </ol>
      </section>

      <section>
        <h2>Debug Events</h2>
        <p>Tool calls, tool results, and context operations stay out of the visible transcript.</p>
        <ol id="debug-events">
          <li :if={@view.events == []}>No debug events yet.</li>
          <li :for={event <- @view.events}>
            <code>{event.seq}: {event.label}</code>
            <pre>{inspect(event.payload, pretty: true)}</pre>
          </li>
        </ol>
      </section>

      <section>
        <h2>Runtime Context</h2>
        <pre>{inspect(@view.runtime_context, pretty: true)}</pre>
      </section>
    </main>
    """
  end
end
