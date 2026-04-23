defmodule BaguConsumer.Accounts do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(BaguConsumer.Accounts.SecureNote)
  end
end
