defmodule Lichat.MixProject do
  use Mix.Project

  def project do
    [
      app: :lichat,
      version: "0.2.4",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        lichat: [
          include_executables_for: [:unix],
          steps: [:assemble, :tar],
          applications: [lichat: :permanent],
          version: {:from_app, :lichat},
          config_providers: [
            {Config.Reader, {:system, "RELEASE_ROOT", "/config/secret.exs"}}
          ]
        ]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :crypto, :eldap, :ssl, :sasl],
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
      {:ex_unicode, "~> 1.0"},
      {:postgrex, "~> 0.15.8"},
      {:ayesql, "~> 1.1"},
      {:image, "~> 0.37"},
      {:observer_cli, "~> 1.7"}
    ]
  end
end
