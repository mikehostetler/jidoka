defmodule Jidoka.Signals do
  @moduledoc false

  alias Jido.Signal

  @source "/jidoka/agent"

  @spec command(String.t(), atom() | String.t(), map(), map()) :: Signal.t()
  def command(session_ref, action, data \\ %{}, meta \\ %{}) do
    signal(
      "jidoka.session.#{session_segment(session_ref)}.command.#{action}",
      session_ref,
      Map.put(data, :meta, base_meta(meta))
    )
  end

  @spec event(String.t(), String.t(), map(), map()) :: Signal.t()
  def event(session_ref, name, data \\ %{}, meta \\ %{}) do
    signal(
      "jidoka.session.#{session_segment(session_ref)}.event.#{name}",
      session_ref,
      Map.put(data, :meta, base_meta(meta))
    )
  end

  @spec session_event_path(String.t()) :: String.t()
  def session_event_path(session_ref) do
    "jidoka.session.#{session_segment(session_ref)}.event.**"
  end

  @spec session_path(String.t()) :: String.t()
  def session_path(session_ref) do
    "jidoka.session.#{session_segment(session_ref)}.**"
  end

  @spec generate_id(String.t()) :: String.t()
  def generate_id(prefix) do
    suffix =
      :crypto.strong_rand_bytes(8)
      |> Base.url_encode64(padding: false)
      |> binary_part(0, 10)

    "#{prefix}_#{suffix}"
  end

  defp signal(type, session_ref, data) do
    Signal.new!(type, data, source: @source, subject: session_ref)
  end

  defp base_meta(meta) do
    Map.merge(
      %{
        correlation_id: generate_id("corr"),
        causation_id: nil
      },
      Map.new(meta)
    )
  end

  defp session_segment(session_ref) do
    Base.url_encode64(session_ref, padding: false)
  end
end
