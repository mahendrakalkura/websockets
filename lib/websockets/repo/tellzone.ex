defmodule WebSockets.Repo.Tellzone do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_tellzones",
    do: (
      Schema.field(:type, :string)
      Schema.field(:name, :string)
      Schema.field(:photo, :string)
      Schema.field(:location, :string)
      Schema.field(:phone, :string)
      Schema.field(:url, :string)
      Schema.field(:hours, :map)
      Schema.field(:point, Geo.Point)
      Schema.field(:status, :string)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)
      Schema.field(:started_at, Ecto.DateTime)
      Schema.field(:ended_at, Ecto.DateTime)
      Schema.belongs_to(:user, WebSockets.Repo.User)
    )
  )
end
