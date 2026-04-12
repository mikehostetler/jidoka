defmodule Jidoka.Persistence.Bedrock do
  @moduledoc """
  Placeholder adapter for a future Bedrock-backed durable store.

  The public persistence boundary exists now so runtime code can depend on the
  behavior without being coupled to a specific backend.
  """

  @behaviour Jidoka.Persistence

  @impl true
  def load(_session_ref), do: {:error, :bedrock_unavailable}

  @impl true
  def save(_session_ref, _state), do: {:error, :bedrock_unavailable}

  @impl true
  def delete(_session_ref), do: {:error, :bedrock_unavailable}

  @impl true
  def list, do: {:ok, []}
end
