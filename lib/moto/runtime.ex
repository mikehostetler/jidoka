defmodule Moto.Runtime do
  @moduledoc """
  Shared Jido runtime instance for Moto agents.
  """

  use Jido, otp_app: :moto
end
