defmodule WebSockets.Repo.Notification do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_notifications",
    do: (
      Schema.field(:type, :string)
      Schema.field(:contents, :map)
      Schema.field(:status, :string)
      Schema.field(:timestamp, Ecto.DateTime)
      Schema.belongs_to(:user, WebSockets.Repo.User)
    )
  )
end
