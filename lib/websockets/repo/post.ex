defmodule WebSockets.Repo.Post do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_posts",
    do: (
      Schema.field(:title, :string)
      Schema.field(:contents, :string)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)
      Schema.field(:expired_at, Ecto.DateTime)
      Schema.belongs_to(:user, WebSockets.Repo.User)
      Schema.belongs_to(:category, WebSockets.Repo.Category)
      Schema.has_many(:attachments, WebSockets.Repo.PostAttachment)
    )
  )
end
