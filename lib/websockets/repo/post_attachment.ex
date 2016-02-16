defmodule WebSockets.Repo.PostAttachment do
  @moduledoc false

  use Ecto.Schema

  schema "api_posts_attachments" do
    field :type, :string
    field :string_original, :string
    field :string_preview, :string
    field :position, :integer
    field :inserted_at, Ecto.DateTime
    field :updated_at, Ecto.DateTime
    belongs_to :post, WebSockets.Repo.Post
    has_many :attachments, WebSockets.Repo.PostAttachment
  end
end
