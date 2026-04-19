defmodule Moto.Agent.SparkDsl do
  @moduledoc false

  use Spark.Dsl, default_extensions: [extensions: [Moto.Agent.Dsl]]
end
