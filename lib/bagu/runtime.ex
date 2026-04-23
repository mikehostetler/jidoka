defmodule Bagu.Runtime do
  @moduledoc """
  Shared Jido runtime instance for Bagu agents.
  """

  use Jido, otp_app: :bagu
end
