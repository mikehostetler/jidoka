defmodule Jidoka.Examples.KitchenSink.Ash.Accounts do
  @moduledoc false

  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(Jidoka.Examples.KitchenSink.Ash.User)
  end
end

defmodule Jidoka.Examples.KitchenSink.Ash.User do
  @moduledoc false

  use Ash.Resource,
    domain: Jidoka.Examples.KitchenSink.Ash.Accounts,
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
