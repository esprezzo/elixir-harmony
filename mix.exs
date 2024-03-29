defmodule Harmony.Mixfile do
  use Mix.Project

  def project do
    [app: :harmony,
     version: "0.1.0",
     elixir: "~> 1.12",
     package: package(),
     description: description(),
     name: "Harmony",
     source_url: "https://github.com/esprezzo/elixir-harmony",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [extra_applications: [:logger],
     mod: {Harmony.Application, []}]
  end

  defp package do
    # These are the default files included in the package
    [
      name: :smart_chain,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["hp"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/esprezzo/elixir-harmony"}
    ]
  end


  defp description do
     """
     This library exists to present a convenient interface to control a full Harmony node from Elixir, abstracting away the need to deal with the JSON-RPC API directly.
     """
  end

  defp deps do
    [
      {:tesla, "~> 1.4"},
      {:hackney, "~> 1.17"}, # optional, but recommended adapter
      {:jason, ">= 1.0.0"}, # optional, required by JSON middleware

      {:ex_abi, "~> 0.5.8"},
      {:ex_keccak, "~> 0.2.0"},
      {:hexate,  ">= 0.6.0"},
 		  {:ex_doc, "~> 0.14", only: :dev}
   ]
  end
end
