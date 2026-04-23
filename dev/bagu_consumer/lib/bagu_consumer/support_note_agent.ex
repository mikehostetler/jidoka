defmodule BaguConsumer.SupportNoteAgent do
  @moduledoc false

  use Bagu.Agent

  agent do
    id :support_note_agent
  end

  defaults do
    model :fast
    instructions "You can help with secure notes."
  end

  capabilities do
    ash_resource BaguConsumer.Accounts.SecureNote
  end
end
