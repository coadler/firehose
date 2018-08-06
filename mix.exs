defmodule Firehose.Mixfile do
  use Mix.Project

  def project do
    [
      app: :firehose,
      version: "0.1.0",
      elixir: "~> 1.7.1",
      start_permanent: Mix.env == :dev,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :httpoison, :amqp],
      mod: {Firehose.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:amqp, "~> 1.0.0-pre.2"},    # Firehose.Nozzle.AMQP
      {:gen_stage, "~> 0.12.2"},    # Firehose.Pump, Firehose.Nozze.*
      {:httpoison, "~> 0.13.0"},    # Firehose.Discord.Utility
      {:poison, "~> 3.1"},          # Firehose.Discord.Utility
      {:websocket_client, "~> 1.3"} # Firehose.Discord.Client
    ]
  end
end
