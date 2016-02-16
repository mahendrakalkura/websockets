defmodule WebSockets.Repo.NetworkTellzone do
  @moduledoc false

  use Ecto.Schema

  schema "api_networks_tellzones" do
    belongs_to :network, WebSockets.Repo.Network
    belongs_to :tellzone, WebSockets.Repo.Tellzone
  end
end
