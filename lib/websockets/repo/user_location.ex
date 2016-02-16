defmodule WebSockets.Repo.UserLocation do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Changeset, as: Changeset
  alias Ecto.DateTime, as: DateTime
  alias Ecto.Schema, as: Schema

  @optional_fields ~w(
    user_id network_id tellzone_id location accuracies_horizontal accuracies_vertical bearing is_casting timestamp
  )
  @required_fields ~w(point)

  Schema.schema(
    "api_users_locations",
    do: (
      Schema.field(:location, :string, default: "")
      Schema.field(:point, Geo.Point)
      Schema.field(:accuracies_horizontal, :float, default: 0.0)
      Schema.field(:accuracies_vertical, :float, default: 0.0)
      Schema.field(:bearing, :integer, default: 0)
      Schema.field(:is_casting, :boolean, default: true)
      Schema.field(:timestamp, Ecto.DateTime)
      Schema.belongs_to(:user, WebSockets.Repo.User)
      Schema.belongs_to(:network, WebSockets.Repo.Network)
      Schema.belongs_to(:tellzone, WebSockets.Repo.Tellzone)
    )
  )

  def changeset(user_location, parameters \\ :empty) do
    user_location
    |> Changeset.cast(parameters, @required_fields, @optional_fields)
    |> timestamp()
  end

  def timestamp(parameters) do
    Changeset.change(parameters, %{:timestamp => DateTime.utc()})
  end
end
