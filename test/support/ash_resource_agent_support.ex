defmodule BaguTest.Support.AshResourceAgent do
  use Bagu.Agent

  agent do
    id :ash_resource_agent
  end

  defaults do
    model :fast
    instructions "You can use Ash resource tools."
  end

  capabilities do
    ash_resource BaguTest.Support.User
  end
end
