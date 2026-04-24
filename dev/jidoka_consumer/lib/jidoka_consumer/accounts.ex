defmodule JidokaConsumer.Accounts do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(JidokaConsumer.Accounts.SecureNote)
  end
end
