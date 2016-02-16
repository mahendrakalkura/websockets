defmodule WebSockets.Repo.MessageAttachment do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Changeset, as: Changeset
  alias Ecto.Schema, as: Schema

  @optional_fields ~w()
  @required_fields ~w(string position)

  Schema.schema(
    "api_messages_attachments",
    do: (
      Schema.field(:string, :string)
      Schema.field(:position, :integer)
      Schema.belongs_to(:message, WebSockets.Repo.Message)
    )
  )

  def changeset(attachment, parameters \\ :empty) do
    attachment
    |> Changeset.cast(parameters, @required_fields, @optional_fields)
  end
end
