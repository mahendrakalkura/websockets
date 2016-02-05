defmodule WebSockets.Mixfile do
  @moduledoc false

  use Mix.Project

  def application() do
    [
      applications: [
        :amqp,
        :comeonin,
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
        :tzdata,
      ],
      mod: {WebSockets, []},
    ]
  end

  def deps() do
    [
      {:amqp, "0.1.4"},
      {:comeonin, "2.1.0"},
      {:cowboy, "1.0.0"},
      {:credo, "0.3.0-dev"},
      {:dogma, "0.0.11"},
      {:ecto, "1.1.3"},
      {:exjsx, "3.2.0"},
      {:exsentry, "0.2.1"},
      {:geo, "1.0.0"},
      {:poison, "1.5.2"},
      {:postgrex, "0.11.0"},
      {:timex, "1.0.0"},
    ]
  end

  def project() do
    [
      app: :websockets,
      deps: deps,
      elixir: "~> 1.2.0",
      version: "0.0.1"
    ]
  end
end
