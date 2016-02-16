defmodule WebSockets.Repo.MasterTell do
  @moduledoc false

  use Ecto.Schema

  schema "api_master_tells" do
    field :contents, :string
    field :position, :integer
    field :is_visible, :boolean
    field :inserted_at, Ecto.DateTime
    field :updated_at, Ecto.DateTime
    belongs_to :created_by, WebSockets.Repo.User
    belongs_to :owned_by, WebSockets.Repo.User
  end
end
