defmodule WebSockets.Repo.Tellcard do
  @moduledoc false

  use Ecto.Schema

  schema "api_tellcards" do
    field :location, :string
    field :viewed_at, Ecto.DateTime
    field :saved_at, Ecto.DateTime
    belongs_to :user_source, WebSockets.Repo.User
    belongs_to :user_destination, WebSockets.Repo.User
    belongs_to :network, WebSockets.Repo.Network
    belongs_to :tellzone, WebSockets.Repo.Tellzone
  end
end
