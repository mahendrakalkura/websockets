defmodule WebSockets.Repo.UserStatus do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_users_statuses",
    do: (
      Schema.field(:string, :string)
      Schema.field(:title, :string)
      Schema.field(:url, :string)
      Schema.field(:notes, :string)
      Schema.belongs_to(:user, WebSockets.Repo.User)
      Schema.has_many(:attachments, WebSockets.Repo.UserStatusAttachments)
    )
  )
end
