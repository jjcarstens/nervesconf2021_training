defmodule Setup.MixProject do
  use Mix.Project

  def project do
    [
      app: :setup,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Setup.Application, []}
    ]
  end

  defp deps do
    [
      {:mdns_lite, "~> 0.8"},
      {:vintage_net, "~> 0.11", runtime: false, override: true}
    ]
  end
end
