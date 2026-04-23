defmodule Bagu.Workflow.SparkDsl do
  @moduledoc false

  use Spark.Dsl, default_extensions: [extensions: [Bagu.Workflow.Dsl]]
end
