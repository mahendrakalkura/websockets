defmodule WebSockets.Repo.UserSettings do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_users_settings",
    do: (
      Schema.field(:key, :string)
      Schema.field(:value, :string)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)
      Schema.belongs_to(:user, WebSockets.Repo.User)
    )
  )
end
