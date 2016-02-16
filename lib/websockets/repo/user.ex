defmodule WebSockets.Repo.User do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_users",
    do: (
      Schema.field(:email, :string)
      Schema.field(:photo_original, :string)
      Schema.field(:photo_preview, :string)
      Schema.field(:first_name, :string)
      Schema.field(:last_name, :string)
      Schema.field(:date_of_birth, Ecto.Date)
      Schema.field(:gender, :string)
      Schema.field(:location, :string)
      Schema.field(:description, :string)
      Schema.field(:phone, :string)
      Schema.field(:point, Geo.Point)
      Schema.field(:is_signed_in, :boolean)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)
      Schema.belongs_to(:tellzone, WebSockets.Repo.Tellzone)
      Schema.has_many(:settings, WebSockets.Repo.UserSettings)
    )
  )
end
