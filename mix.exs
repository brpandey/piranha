defmodule Piranha.Mixfile do
  use Mix.Project

  def project do
    [app: :piranha,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [applications: [:logger, :maru, :timex], mod: {Piranha, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:maru, "~> 0.11.3"},
      {:hashids, "~> 2.0"},
      {:timex, "~> 3.1"},
      {:poison, "~> 3.0"},
      {:httpoison, "~> 0.11.0"},
      {:amnesia, "~> 0.2.5"}
    ]
  end
end
