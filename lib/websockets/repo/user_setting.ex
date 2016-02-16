defmodule WebSockets.Repo.UserSettings do
  @moduledoc false

  use Ecto.Schema

  schema "api_users_settings" do
    field :key, :string
    field :value, :string
    field :inserted_at, Ecto.DateTime
    field :updated_at, Ecto.DateTime
    belongs_to :user, WebSockets.Repo.User
  end
end
