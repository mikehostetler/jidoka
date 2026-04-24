defmodule BaguConsumerWeb.SupportChatView do
  @moduledoc """
  Phoenix-facing view adapter for the support note agent.

  This is the spike boundary: the Bagu agent owns execution and `Jido.Thread`
  owns the canonical event log. The LiveView owns rendering and optimistic UI
  state. This module projects the agent into UI data without claiming that the
  visible transcript is the same thing as the LLM context.
  """

  @agent BaguConsumer.SupportNoteAgent

  @type t :: %{
          agent_id: String.t(),
          conversation_id: String.t(),
          runtime_context: map(),
          visible_messages: [map()],
          llm_context: [map()],
          events: [map()],
          status: atom(),
          error: String.t() | nil
        }

  @doc "Starts or reuses the agent instance backing a LiveView conversation."
  @spec start_agent(map()) :: {:ok, pid()} | {:error, term()}
  def start_agent(session) when is_map(session) do
    agent_id = agent_id(session)

    case Bagu.whereis(agent_id) do
      nil -> @agent.start_link(id: agent_id)
      pid -> {:ok, pid}
    end
  end

  @doc "Projects the running agent into a LiveView-friendly state map."
  @spec snapshot(pid(), map(), keyword()) :: {:ok, t()} | {:error, term()}
  def snapshot(pid, session, opts \\ []) when is_pid(pid) and is_map(session) do
    with {:ok, projection} <- Bagu.Agent.View.snapshot(pid, opts) do
      {:ok,
       %{
         agent_id: agent_id(session),
         conversation_id: conversation_id(session),
         runtime_context: public_context(session),
         visible_messages: projection.visible_messages,
         llm_context: projection.llm_context,
         events: projection.events,
         status: :idle,
         error: nil
       }}
    end
  end

  @doc "UI hook executed before the blocking chat call starts."
  @spec before_submit(t(), String.t()) :: t()
  def before_submit(view, message) when is_map(view) and is_binary(message) do
    content = String.trim(message)

    if content == "" do
      %{view | status: :idle}
    else
      pending = %{
        id: "pending-" <> Integer.to_string(System.unique_integer([:positive, :monotonic])),
        seq: -1,
        role: :user,
        content: content,
        pending?: true
      }

      %{view | visible_messages: view.visible_messages ++ [pending], status: :running, error: nil}
    end
  end

  @doc "Runs the Bagu chat turn for a LiveView submit event."
  @spec send_message(pid(), String.t(), map()) ::
          {:ok, term()}
          | {:interrupt, Bagu.Interrupt.t()}
          | {:handoff, Bagu.Handoff.t()}
          | {:error, term()}
  def send_message(pid, message, session)
      when is_pid(pid) and is_binary(message) and is_map(session) do
    case String.trim(message) do
      "" ->
        {:error, Bagu.Error.validation_error("Message must not be empty.", field: :message)}

      content ->
        @agent.chat(pid, content,
          conversation: conversation_id(session),
          context: runtime_context(session)
        )
    end
  end

  @doc "UI hook executed after a Bagu chat turn returns."
  @spec after_result(pid(), map(), term()) :: {:ok, t()} | {:error, term()}
  def after_result(pid, session, result) when is_pid(pid) and is_map(session) do
    with {:ok, view} <- snapshot(pid, session) do
      {:ok, apply_result(view, result)}
    end
  end

  @spec ui_hooks() :: [atom()]
  def ui_hooks, do: [:before_submit, :after_result, :snapshot]

  defp apply_result(view, {:error, reason}) do
    %{view | status: :error, error: Bagu.format_error(reason)}
  end

  defp apply_result(view, {:interrupt, interrupt}) do
    %{view | status: :interrupted, error: interrupt.message}
  end

  defp apply_result(view, {:handoff, handoff}) do
    %{view | status: :handoff, error: "Conversation handed off to #{handoff.to_agent_id}."}
  end

  defp apply_result(view, {:ok, _reply}), do: %{view | status: :idle, error: nil}

  defp runtime_context(session) do
    Map.merge(public_context(session), %{
      actor: %{id: Map.get(session, "user_id", "demo-user")}
    })
  end

  defp public_context(session) do
    %{
      channel: "phoenix_live_view",
      tenant: Map.get(session, "tenant", "demo"),
      session: conversation_id(session)
    }
  end

  defp agent_id(session), do: "support-note-liveview-" <> conversation_id(session)

  defp conversation_id(session) do
    session
    |> Map.get("conversation_id", "demo")
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]+/, "_")
    |> String.trim("_")
    |> case do
      "" -> "demo"
      id -> id
    end
  end
end
