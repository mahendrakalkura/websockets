defmodule WebSockets.Repo.NetworkTellzone do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_networks_tellzones",
    do: (
      Schema.belongs_to(:network, WebSockets.Repo.Network)
      Schema.belongs_to(:tellzone, WebSockets.Repo.Tellzone)
    )
  )
end
