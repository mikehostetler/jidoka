defmodule Jidoka.Signals do
  @moduledoc """
  Small compatibility helper for generating stable test ids.
  """

  @spec generate_id(String.t()) :: String.t()
  def generate_id(prefix) when is_binary(prefix) and byte_size(prefix) > 0 do
    prefix <> "-" <> Integer.to_string(System.unique_integer([:positive, :monotonic]))
  end
end
