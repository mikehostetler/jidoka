defmodule Moto.Agent.Dsl do
  @moduledoc false

  @agent_section %Spark.Dsl.Section{
    name: :agent,
    describe: """
    Configure the Moto agent.
    """,
    schema: [
      name: [
        type: :string,
        required: false,
        doc: "The public agent name. Defaults to the underscored module name."
      ],
      system_prompt: [
        type: :string,
        required: true,
        doc: "The system prompt used for the generated Jido.AI runtime module."
      ]
    ]
  }

  use Spark.Dsl.Extension, sections: [@agent_section]
end
