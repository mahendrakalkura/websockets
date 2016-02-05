defmodule WebSockets.Repo do
  @moduledoc false

  use Ecto.Repo, otp_app: :websockets
end

defmodule WebSockets.Repo.Block do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_blocks",
    do: (
      Schema.field(:timestamp, Ecto.DateTime)
      Schema.belongs_to(:user_source, User)
      Schema.belongs_to(:user_destination, User)
    )
  )
end

defmodule WebSockets.Repo.Category do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_categories",
    do: (
      Schema.field(:name, :string)
    )
  )
end

defmodule WebSockets.Repo.MasterTell do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_master_tells",
    do: (
      Schema.field(:contents, :string)
      Schema.field(:position, :integer)
      Schema.field(:is_visible, :boolean)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)
      Schema.belongs_to(:created_by, User)
      Schema.belongs_to(:owned_by, User)
    )
  )
end

defmodule WebSockets.Repo.Message do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_messages",
    do: (
      Schema.field(:user_source_is_hidden, :boolean)
      Schema.field(:user_destination_is_hidden, :boolean)
      Schema.field(:type, :string)
      Schema.field(:contents, :string)
      Schema.field(:status, :string)
      Schema.field(:is_suppressed, :boolean)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)

      Schema.belongs_to(:user_destination, User)
      Schema.belongs_to(:user_source, User)
      Schema.belongs_to(:user_status, UserStatus)
      Schema.belongs_to(:master_tell, MasterTell)
      Schema.belongs_to(:post, Post)
    )
  )
end

defmodule WebSockets.Repo.MessageAttachment do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_messages_attachments",
    do: (
      Schema.field(:string, :string)
      Schema.field(:position, :integer)
      Schema.belongs_to(:message, Message)
    )
  )
end

defmodule WebSockets.Repo.Network do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_networks",
    do: (
      Schema.field(:name, :string)
      Schema.belongs_to(:user, User)
    )
  )
end

defmodule WebSockets.Repo.NetworkTellzones do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_networks_tellzones",
    do: (
      Schema.belongs_to(:network, Network)
      Schema.belongs_to(:tellzone, Tellzone)
    )
  )
end

defmodule WebSockets.Repo.Notification do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_notifications",
    do: (
      Schema.field(:type, :string)
      Schema.field(:contents, :map)
      Schema.field(:status, :string)
      Schema.field(:timestamp, Ecto.DateTime)
      Schema.belongs_to(:user, User)
    )
  )
end

defmodule WebSockets.Repo.Post do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_posts",
    do: (
      Schema.field(:title, :string)
      Schema.field(:contents, :string)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)
      Schema.field(:expired_at, Ecto.DateTime)
      Schema.belongs_to(:user, User)
      Schema.belongs_to(:category, Category)
    )
  )
end

defmodule WebSockets.Repo.Tellcard do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_tellcards",
    do: (
      Schema.field(:location, :string)
      Schema.field(:viewed_at, Ecto.DateTime)
      Schema.field(:saved_at, Ecto.DateTime)
      Schema.belongs_to(:user_source, User)
      Schema.belongs_to(:user_destination, User)
      Schema.belongs_to(:network, Network)
      Schema.belongs_to(:tellzone, Tellzone)
    )
  )
end

defmodule WebSockets.Repo.Tellzone do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_tellzones",
    do: (
      Schema.field(:type, :string)
      Schema.field(:name, :string)
      Schema.field(:photo, :string)
      Schema.field(:location, :string)
      Schema.field(:phone, :string)
      Schema.field(:url, :string)
      Schema.field(:hours, :map)
      Schema.field(:point, Geo.Point)
      Schema.field(:status, :string)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)
      Schema.field(:started_at, Ecto.DateTime)
      Schema.field(:ended_at, Ecto.DateTime)
      Schema.belongs_to(:user, User)
    )
  )
end

defmodule WebSockets.Repo.User do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_users",
    do: (
      Schema.field(:email, :string)
      Schema.field(:photo_original, :string)
      Schema.field(:photo_preview, :string)
      Schema.field(:first_name, :string)
      Schema.field(:last_name, :string)
      Schema.field(:date_of_birth, Ecto.Date)
      Schema.field(:gender, :string)
      Schema.field(:location, :string)
      Schema.field(:description, :string)
      Schema.field(:phone, :string)
      Schema.field(:point, Geo.Point)
      Schema.field(:is_signed_in, :boolean)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)
      Schema.belongs_to(:tellzone, Tellzone)
    )
  )
end

defmodule WebSockets.Repo.UserLocation do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_users_locations",
    do: (
      Schema.field(:location, :string)
      Schema.field(:point, Geo.Point)
      Schema.field(:accuracies_horizontal, :float)
      Schema.field(:accuracies_vertical, :float)
      Schema.field(:bearing, :integer)
      Schema.field(:is_casting, :boolean)
      Schema.field(:timestamp, Ecto.DateTime)
      Schema.belongs_to(:user, User)
      Schema.belongs_to(:network, Network)
      Schema.belongs_to(:tellzone, Tellzone)
    )
  )
end

defmodule WebSockets.Repo.UserSettings do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_users_settings",
    do: (
      Schema.field(:key, :string)
      Schema.field(:value, :string)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)
      Schema.belongs_to(:user, User)
    )
  )
end

defmodule WebSockets.Repo.UserStatus do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_users_statuses",
    do: (
      Schema.field(:string, :string)
      Schema.field(:title, :string)
      Schema.field(:url, :string)
      Schema.field(:notes, :string)
      Schema.belongs_to(:user, User)
    )
  )
end

defmodule WebSockets.Repo.UserStatusAttachments do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_users_statuses_attachments",
    do: (
      Schema.field(:string_original, :string)
      Schema.field(:string_preview, :string)
      Schema.field(:position, :integer)
      Schema.belongs_to(:user_status, UserStatus)
    )
  )
end
