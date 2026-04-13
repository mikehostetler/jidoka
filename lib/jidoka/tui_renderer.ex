defmodule Jidoka.TuiRenderer do
  @moduledoc """
  Stateless rendering helpers for shell output and render models.
  """

  alias Jidoka.TuiServer.State

  @activity_fallback [
    "no runtime events yet",
    "waiting for snapshots or event stream"
  ]

  @prompt "jidoka> "

  def render_model(%State{} = state) do
    status_lines = status_lines(state)
    activity_lines = activity_lines(state)
    input_lines = input_lines(state)

    %{
      status: %{
        heading: "status",
        lines: status_lines
      },
      activity: %{
        heading: "activity",
        lines: activity_lines
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
      render_region("activity", model.activity.lines),
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

  defp activity_lines(state) do
    case state.activity_lines do
      [] ->
        @activity_fallback

      lines ->
        lines
    end
  end

  defp input_lines(state) do
    ["prompt=#{@prompt}", "buffer=#{state.input_buffer || ""}"]
  end

  defp format_connection(%{mode: :attached}), do: "attached"
  defp format_connection(%{mode: :recoverable}), do: "recoverable"
  defp format_connection(_), do: "unknown"
end
