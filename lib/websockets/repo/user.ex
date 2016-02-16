defmodule WebSockets.Repo.User do
  @moduledoc false

  use Ecto.Schema

  schema "api_users" do
    field :email, :string
    field :photo_original, :string
    field :photo_preview, :string
    field :first_name, :string
    field :last_name, :string
    field :date_of_birth, Ecto.Date
    field :gender, :string
    field :location, :string
    field :description, :string
    field :phone, :string
    field :point, Geo.Point
    field :is_signed_in, :boolean
    field :inserted_at, Ecto.DateTime
    field :updated_at, Ecto.DateTime
    belongs_to :tellzone, WebSockets.Repo.Tellzone
    has_many :settings, WebSockets.Repo.UserSettings
  end
end
