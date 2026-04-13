defmodule Jidoka.SessionBusPath do
  @moduledoc false

  @prefix "jidoka.session."

  @spec events(String.t()) :: String.t()
  def events(session_ref) when is_binary(session_ref) do
    encoded(session_ref) <> ".events"
  end

  @spec wildcard(String.t()) :: String.t()
  def wildcard(session_ref) when is_binary(session_ref) do
    encoded(session_ref) <> ".**"
  end

  defp encoded(session_ref) do
    @prefix <> Base.url_encode64(session_ref, padding: false)
  end
end
