defmodule WebSockets.Repo.Network do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_networks",
    do: (
      Schema.field(:name, :string)
      Schema.belongs_to(:user, WebSockets.Repo.User)
    )
  )
end
