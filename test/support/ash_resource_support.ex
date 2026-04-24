defmodule JidokaTest.Support.Accounts do
  use Ash.Domain, validate_config_inclusion?: false

  resources do
    resource(JidokaTest.Support.User)
  end
end

defmodule JidokaTest.Support.User do
  use Ash.Resource,
    domain: JidokaTest.Support.Accounts,
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
