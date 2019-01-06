defmodule SensorSampleIndexer.MixProject do
  use Mix.Project

  def project do
    [
      app: :sensor_sample_indexer,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {SensorSampleIndexer, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 1.1"},
      {:connection, "~> 1.0.4"},
      {:gen_stage, "~> 0.14"},
      {:poison, "~> 4.0"},
    ]
  end
end
