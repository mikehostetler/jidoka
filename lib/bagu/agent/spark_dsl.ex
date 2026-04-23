defmodule Bagu.Agent.SparkDsl do
  @moduledoc false

  use Spark.Dsl, default_extensions: [extensions: [Bagu.Agent.Dsl]]
end
