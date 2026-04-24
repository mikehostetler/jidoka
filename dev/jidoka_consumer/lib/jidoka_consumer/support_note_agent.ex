defmodule JidokaConsumer.SupportNoteAgent do
  @moduledoc false

  use Jidoka.Agent

  agent do
    id :support_note_agent
  end

  defaults do
    model :fast
    instructions "You can help with secure notes."
  end

  capabilities do
    ash_resource JidokaConsumer.Accounts.SecureNote
  end
end
