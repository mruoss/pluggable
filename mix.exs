defmodule Pluggable.MixProject do
  use Mix.Project

  @app :pluggable
  @source_url "https://github.com/mruoss/#{@app}"
  @version "1.1.0"

  def project do
    [
      app: @app,
      description: "A Plug-like pipeline creator",
      version: @version,
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env()),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: cli_env(),
      consolidate_protocols: Mix.env() != :test,
      dialyzer: dialyzer()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:dialyxir, "~> 1.4.0", only: [:dev, :test], runtime: false},
      # {:ex_doc, "~> 0.29", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},

      # Test deps
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp docs do
    [
      # The main page in the docs
      main: "Pluggable.Token",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md"
      ]
    ]
  end

  defp cli_env do
    [
      coveralls: :test,
      "coveralls.detail": :test,
      "coveralls.post": :test,
      "coveralls.html": :test,
      "coveralls.travis": :test,
      "coveralls.github": :test,
      "coveralls.xml": :test,
      "coveralls.json": :test
    ]
  end

  defp package do
    [
      name: @app,
      maintainers: ["Michael Ruoss"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://hexdocs.pm/#{@app}/changelog.html",
        "Sponsor" => "https://github.com/sponsors/mruoss"
      },
      files: ["lib", "mix.exs", "README.md", "LICENSE", "CHANGELOG.md", ".formatter.exs"]
    ]
  end

  defp dialyzer do
    [
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_core_path: "priv/plts",
      plt_file: {:no_warn, "priv/plts/#{@app}.plt"}
    ]
  end
end
