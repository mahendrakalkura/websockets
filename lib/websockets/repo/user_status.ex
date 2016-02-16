defmodule WebSockets.Repo.UserStatus do
  @moduledoc false

  use Ecto.Schema

  schema "api_users_statuses" do
    field :string, :string
    field :title, :string
    field :url, :string
    field :notes, :string
    belongs_to :user, WebSockets.Repo.User
    has_many :attachments, WebSockets.Repo.UserStatusAttachments
  end
end
