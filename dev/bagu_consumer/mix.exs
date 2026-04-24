defmodule BaguConsumer.MixProject do
  use Mix.Project

  def project do
    [
      app: :bagu_consumer,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {BaguConsumer.Application, []}
    ]
  end

  defp deps do
    [
      {:ash, "~> 3.24"},
      {:ash_jido, path: "../../../ash_jido", override: true},
      {:jido, path: "../../../jido", override: true},
      {:bagu, path: "../.."},
      {:bandit, "~> 1.5"},
      {:floki, ">= 0.34.0", only: :test},
      {:jason, "~> 1.4"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix, "~> 1.8"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_pubsub, "~> 2.1"},
      {:picosat_elixir, "~> 0.2", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      test: ["test"]
    ]
  end
end
