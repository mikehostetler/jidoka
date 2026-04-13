defmodule Jidoka.TuiRenderer do
  @moduledoc """
  Stateless rendering helpers for shell output and render models.
  """

  alias Jidoka.TuiServer.State

  @event_fallback [
    "no runtime events yet",
    "waiting for snapshots or event stream"
  ]

  @focused_progress_fallback [
    "no attempt progress yet",
    "waiting for attempt progress event"
  ]

  @prompt "jidoka> "

  def render_model(%State{} = state) do
    status_lines = status_lines(state)
    focused_run_lines = focused_run_lines(state)
    event_lines = event_lines(state)
    input_lines = input_lines(state)

    %{
      status: %{
        heading: "status",
        lines: status_lines
      },
      focused_run: %{
        heading: "focused run",
        lines: focused_run_lines
      },
      events: %{
        heading: "event stream",
        lines: event_lines
      },
      input: %{
        heading: "operator input",
        lines: input_lines
      }
    }
  end

  def render(%State{} = state) do
    model = render_model(state)

    [
      render_region("status", model.status.lines),
      render_region("focused run", model.focused_run.lines),
      render_region("event stream", model.events.lines),
      render_region("operator input", model.input.lines)
    ]
    |> Enum.join("\n")
  end

  defp render_region(name, lines) do
    heading = "[#{name}]"
    body = lines |> Enum.join("\n")
    heading <> "\n" <> body
  end

  defp status_lines(state) do
    connection_label = format_connection(state)

    [
      "connection=#{connection_label}",
      "session_id=#{state.session_ref || "<none>"}",
      "session_status=#{inspect(state.session_status)}",
      "active_run_id=#{state.active_run_id || "<none>"}",
      "active_run_status=#{inspect(state.active_run_status)}",
      "active_attempt_id=#{state.active_attempt_id || "<none>"}",
      "active_attempt_status=#{inspect(state.active_attempt_status)}",
      "recoverable_reason=#{inspect(state.recoverable_reason)}"
    ]
  end

  defp event_lines(state) do
    case state.activity_lines do
      [] ->
        @event_fallback

      lines ->
        lines
    end
  end

  defp focused_run_lines(state) do
    [
      "run_id=#{state.active_run_id || "<none>"}",
      "run_status=#{inspect(state.active_run_status)}",
      "run_task=#{state.active_run_task || "<none>"}",
      "run_attempt_count=#{state.active_run_attempt_count}",
      "attempt_id=#{state.active_attempt_id || "<none>"}",
      "attempt_number=#{state.active_attempt_number || "<none>"}",
      "attempt_status=#{inspect(state.active_attempt_status)}",
      "recent_progress:",
      "",
      maybe_progress_lines(state.focused_progress_lines)
    ]
    |> List.flatten()
  end

  defp input_lines(state) do
    ["prompt=#{@prompt}", "buffer=#{state.input_buffer || ""}"]
  end

  defp maybe_progress_lines([]), do: @focused_progress_fallback
  defp maybe_progress_lines(lines), do: Enum.map(lines, &"  #{&1}")

  defp format_connection(%{mode: :attached}), do: "attached"
  defp format_connection(%{mode: :recoverable}), do: "recoverable"
  defp format_connection(_), do: "unknown"
end
