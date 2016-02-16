defmodule WebSockets.Repo.MasterTell do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_master_tells",
    do: (
      Schema.field(:contents, :string)
      Schema.field(:position, :integer)
      Schema.field(:is_visible, :boolean)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)
      Schema.belongs_to(:created_by, WebSockets.Repo.User)
      Schema.belongs_to(:owned_by, WebSockets.Repo.User)
    )
  )
end
