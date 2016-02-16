defmodule WebSockets.Repo.UserStatusAttachments do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_users_statuses_attachments",
    do: (
      Schema.field(:string_original, :string)
      Schema.field(:string_preview, :string)
      Schema.field(:position, :integer)
      Schema.belongs_to(:user_status, WebSockets.Repo.UserStatus)
    )
  )
end
