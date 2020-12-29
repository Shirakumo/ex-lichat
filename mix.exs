defmodule Lichat.MixProject do
  use Mix.Project

  def project do
    [
      app: :lichat,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        lichat: [
          include_executables_for: [:unix],
          steps: [:assemble, :tar],
          applications: [lichat: :permanent],
          version: {:from_app, :lichat}
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto, :eldap],
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
      {:hashids, "~> 2.0"},
      {:mime, "~> 1.2"},
      {:ex_unicode, "~> 1.0"}
    ]
  end
end
