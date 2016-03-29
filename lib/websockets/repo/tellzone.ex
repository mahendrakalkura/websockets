defmodule WebSockets.Repo.Tellzone do
  @moduledoc false

  use Ecto.Schema

  schema "api_tellzones" do
    field :type, :string
    field :name, :string
    field :photo, :string
    field :location, :string
    field :phone, :string
    field :url, :string
    field :hours, :string
    field :point, Geo.Point
    field :status, :string
    field :inserted_at, Ecto.DateTime
    field :updated_at, Ecto.DateTime
    field :started_at, Ecto.DateTime
    field :ended_at, Ecto.DateTime
    belongs_to :user, WebSockets.Repo.User
  end
end
