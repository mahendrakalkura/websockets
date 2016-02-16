defmodule WebSockets.Repo.Category do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Schema, as: Schema

  Schema.schema(
    "api_categories",
    do: (
      Schema.field(:name, :string)
    )
  )
end
