defmodule Lichat.MixProject do
  use Mix.Project

  def project do
    [
      app: :lichat,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      env: [profile_lifetime: 60*60*24*365,
            acceptors: 2,
            port: 1111,
            name: "Lichat"],
      mod: {Lichat, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_parsec, "~> 0.6"},
      {:hashids, "~> 2.0"}
    ]
  end
end
