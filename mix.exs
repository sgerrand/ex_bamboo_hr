defmodule BambooHR.MixProject do
  use Mix.Project

  @repo_url "https://github.com/sgerrand/ex_bamboo_hr"

  def project do
    [
      app: :bamboo_hr,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # Hex
      description: "Elixir client for the Bamboo HR API",
      homepage_url: @repo_url,
      package: package(),
      source_url: @repo_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:req, "~> 0.5.0"},
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.0", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:expublish, "~> 2.5", only: [:dev], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      maintainers: ["Sasha Gerrand"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @repo_url,
        "Sponsor" => "https://github.com/sponsors/sgerrand"
      },
      files: ~w(lib LICENSE mix.exs README.md)
    ]
  end
end
