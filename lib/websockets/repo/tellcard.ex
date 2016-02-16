defmodule WebSockets.Repo.Tellcard do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_tellcards",
    do: (
      Schema.field(:location, :string)
      Schema.field(:viewed_at, Ecto.DateTime)
      Schema.field(:saved_at, Ecto.DateTime)
      Schema.belongs_to(:user_source, WebSockets.Repo.User)
      Schema.belongs_to(:user_destination, WebSockets.Repo.User)
      Schema.belongs_to(:network, WebSockets.Repo.Network)
      Schema.belongs_to(:tellzone, WebSockets.Repo.Tellzone)
    )
  )
end
