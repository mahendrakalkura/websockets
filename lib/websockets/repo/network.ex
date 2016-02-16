defmodule WebSockets.Repo.Network do
  @moduledoc false

  use Ecto.Schema

  schema "api_networks" do
    field :name, :string
    belongs_to :user, WebSockets.Repo.User
  end
end
