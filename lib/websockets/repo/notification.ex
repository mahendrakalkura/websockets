defmodule WebSockets.Repo.Notification do
  @moduledoc false

  use Ecto.Schema

  schema "api_notifications" do
    field :type, :string
    field :contents, :map
    field :status, :string
    field :timestamp, Ecto.DateTime
    belongs_to :user, WebSockets.Repo.User
  end
end
