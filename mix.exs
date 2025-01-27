defmodule BambooHR.MixProject do
  use Mix.Project

  def project do
    [
      app: :bamboo_hr,
      version: "0.0.0-dev",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: "Elixir client for the Bamboo HR API",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Sasha Gerrand"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/sgerrand/ex_bamboo_hr",
        "Sponsor" => "https://github.com/sponsors/sgerrand"
      },
      files: ~w(lib LICENSE mix.exs README.md)
    ]
  end
end
