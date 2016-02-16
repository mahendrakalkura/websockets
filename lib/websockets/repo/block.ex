defmodule WebSockets.Repo.Block do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Changeset, as: Changeset
  alias Ecto.DateTime, as: DateTime

  @optional_fields ~w(timestamp)
  @required_fields ~w(user_source_id user_destination_id)

  schema "api_blocks" do
    field :timestamp, Ecto.DateTime
    belongs_to :user_source, WebSockets.Repo.User
    belongs_to :user_destination, WebSockets.Repo.User
  end

  def changeset(block, parameters \\ :empty) do
    block
    |> Changeset.cast(parameters, @required_fields, @optional_fields)
    |> timestamp()
  end

  def timestamp(parameters) do
    Changeset.change(parameters, %{:timestamp => DateTime.utc()})
  end
end
