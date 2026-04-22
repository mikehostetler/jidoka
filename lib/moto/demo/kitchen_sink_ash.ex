defmodule Moto.Demo.KitchenSinkAsh.Accounts do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(Moto.Demo.KitchenSinkAsh.User)
  end
end

defmodule Moto.Demo.KitchenSinkAsh.User do
  @moduledoc false

  use Ash.Resource,
    domain: Moto.Demo.KitchenSinkAsh.Accounts,
    extensions: [AshJido],
    validate_domain_inclusion?: false

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string)
  end

  actions do
    default_accept([:name])
    create(:create)
    read(:read)
  end

  jido do
    action(:create)
    action(:read)
  end
end
