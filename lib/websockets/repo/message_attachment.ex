defmodule WebSockets.Repo.MessageAttachment do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Changeset, as: Changeset

  @optional_fields ~w()
  @required_fields ~w(string position)

  schema "api_messages_attachments" do
    field :string, :string
    field :position, :integer
    belongs_to :message, WebSockets.Repo.Message
  end

  def changeset(attachment, parameters \\ :empty) do
    attachment
    |> Changeset.cast(parameters, @required_fields, @optional_fields)
  end
end
