defmodule WebSockets.Repo.PostAttachment do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_posts_attachments",
    do: (
      Schema.field(:type, :string)
      Schema.field(:string_original, :string)
      Schema.field(:string_preview, :string)
      Schema.field(:position, :integer)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)
      Schema.belongs_to(:post, WebSockets.Repo.Post)
      Schema.has_many(:attachments, WebSockets.Repo.PostAttachment)
    )
  )
end
