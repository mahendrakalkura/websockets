defmodule WebSockets.Repo.UserLocation do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Changeset, as: Changeset
  alias Ecto.DateTime, as: DateTime

  @optional_fields ~w(
    user_id
    network_id
    tellzone_id
    location
    accuracies_horizontal
    accuracies_vertical
    bearing
    is_casting
    timestamp
  )
  @required_fields ~w(point)

  schema "api_users_locations" do
    field :location, :string, default: ""
    field :point, Geo.Point
    field :accuracies_horizontal, :float, default: 0.0
    field :accuracies_vertical, :float, default: 0.0
    field :bearing, :integer, default: 0
    field :is_casting, :boolean, default: true
    field :timestamp, Ecto.DateTime
    belongs_to :user, WebSockets.Repo.User
    belongs_to :network, WebSockets.Repo.Network
    belongs_to :tellzone, WebSockets.Repo.Tellzone
  end

  def changeset(user_location, parameters \\ :empty) do
    user_location
    |> Changeset.cast(parameters, @required_fields, @optional_fields)
    |> timestamp()
  end

  def timestamp(parameters) do
    Changeset.change(parameters, %{:timestamp => DateTime.utc()})
  end
end
