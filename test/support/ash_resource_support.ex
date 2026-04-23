defmodule BaguTest.Support.Accounts do
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(BaguTest.Support.User)
  end
end

defmodule BaguTest.Support.User do
  use Ash.Resource,
    domain: BaguTest.Support.Accounts,
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
