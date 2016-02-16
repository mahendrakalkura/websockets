defmodule WebSockets.Repo.UserStatusAttachments do
  @moduledoc false

  use Ecto.Schema

  schema "api_users_statuses_attachments" do
    field :string_original, :string
    field :string_preview, :string
    field :position, :integer
    belongs_to :user_status, WebSockets.Repo.UserStatus
  end
end
