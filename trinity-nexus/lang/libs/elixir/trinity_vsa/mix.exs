defmodule TrinityVsa.MixProject do
  use Mix.Project

  def project do
    [
      app: :trinity_vsa,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Vector Symbolic Architecture with balanced ternary arithmetic",
      package: package()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    []
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/gHashTag/trinity"}
    ]
  end
end
