defmodule WebSockets.Repo.Post do
  @moduledoc false

  use Ecto.Schema

  schema "api_posts" do
    field :title, :string
    field :contents, :string
    field :inserted_at, Ecto.DateTime
    field :updated_at, Ecto.DateTime
    field :expired_at, Ecto.DateTime
    belongs_to :user, WebSockets.Repo.User
    belongs_to :category, WebSockets.Repo.Category
    has_many :attachments, WebSockets.Repo.PostAttachment
  end
end
