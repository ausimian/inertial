defmodule Inertial.MixProject do
  use Mix.Project

  @version "2.0.0"
  @source_url "https://github.com/ausimian/inertial"

  def project do
    [
      app: :inertial,
      description: "Event notifications for network interfaces",
      version: @version,
      elixir: "~> 1.16",
      compilers: [:elixir_make] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: docs(),
      source_url: @source_url
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Inertial.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:elixir_make, "~> 0.9", runtime: false},
      {:typedstruct, "~> 0.5", runtime: false},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["Nick Gunn"],
      links: %{"GitHub" => @source_url},
      licenses: ["MIT"],
      files: ~w(lib c_src Makefile CHANGELOG.md LICENSE.md mix.exs README.md .formatter.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "#{@version}",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
