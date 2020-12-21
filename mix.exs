defmodule MMO.MixProject do
  use Mix.Project

  def project do
    [
      app: :mmo,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        unix: release_for(:unix),
        windows: release_for(:windows)
      ],
      default_release: :unix
    ]
  end

  defp release_for(platform) when platform in [:unix, :windows] do
    [
      include_executables_for: [platform],
      applications: [runtime_tools: :permanent]
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MMO.Application, []}
    ]
  end

  defp deps do
    [
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false}
    ]
  end
end
