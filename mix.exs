defmodule WebSockets.Mixfile do
  @moduledoc ""

  use Mix.Project

  def application() do
    [
      applications: [
        :amqp,
        :cowboy,
        :credo,
        :dogma,
        :ecto,
        :exjsx,
        :exsentry,
        :geo,
        :logger,
        :postgrex,
        :ranch,
      ],
      mod: {WebSockets, []},
    ]
  end

  def project() do
    [
      app: :websockets,
      deps: deps,
      elixir: "~> 1.2.0",
      version: "0.0.1",
    ]
  end

  defp deps() do
    [
      {:amqp, "0.1.4"},
      {:cowboy, "1.0.0"},
      {:credo, "0.3.0-dev"},
      {:dogma, "0.0.11"},
      {:ecto, "1.1.3"},
      {:exjsx, "3.2.0"},
      {:exsentry, "0.2.1"},
      {:geo, "1.0.0"},
      {:postgrex, "0.11.0"},
    ]
  end
end
