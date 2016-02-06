defmodule WebSockets.Repo do
  @moduledoc false

  require Map

  use Ecto.Repo, otp_app: :websockets

  def get_master_tell(nil) do
    nil
  end

  def get_master_tell(master_tell) do
    %{
      "id" => master_tell.id,
      "created_by_id" => master_tell.created_by_id,
      "owned_by_id" => master_tell.owned_by_id,
      "contents" => master_tell.contents,
      "position" => master_tell.position,
      "is_visible" => master_tell.is_visible,
      "inserted_at" => master_tell.inserted_at,
      "updated_at" => master_tell.updated_at
    }
  end

  def get_message(nil) do
    nil
  end

  def get_message(message) do
    %{
      "id" => message.id,
      "user_source_is_hidden" => message.user_source_is_hidden,
      "user_source_id" => message.user_source_id,
      "user_source" => get_user(message.user_source),
      "user_destination_is_hidden" => message.user_destination_is_hidden,
      "user_destination_id" => message.user_destination_id,
      "user_destination" => get_user(message.user_destination),
      "master_tell_id" => message.master_tell_id,
      "master_tell" => get_master_tell(message.master_tell),
      "user_status_id" => message.user_status_id,
      "user_status" => get_user_status(message.user_status),
      "post" => get_post(message.post),
      "post_id" => message.post_id,
      "type" => message.type,
      "contents" => message.contents,
      "status" => message.status,
      "inserted_at" => message.inserted_at,
      "updated_at" => message.inserted_at,
      "attachments" => get_message_attachments(message.attachments)
    }
  end

  def get_message_attachments(attachments) do
    Enum.map(
      attachments,
      fn(attachment) ->
        %{
          "id" => attachment.id,
          "string" => attachment.string,
          "position" => attachment.position
        }
      end
    )
  end

  def get_notification(nil) do
    nil
  end

  def get_notification(notification) do
    %{
      "id" => notification.id,
      "user_id" => notification.user_id,
      "type" => notification.type,
      "contents" => notification.contents,
      "status" => notification.status,
      "timestamp" => notification.timestamp
    }
  end

  def get_post(nil) do
    nil
  end

  def get_post(post) do
    %{
      "id" => post.id,
      "user_id" => post.user_id,
      "tellzones_id" => post.tellzones_id,
      "category_id" => post.category_id,
      "title" => post.title,
      "contents" => post.contents,
      "inserted_at" => post.inserted_at,
      "updated_at" => post.updated_at,
      "expired_at" => post.expired_at,
      "attachments" => get_post_attachments(post.attachments)
    }
  end

  def get_post_attachments(attachments) do
    Enum.map(
      attachments,
      fn(attachment) ->
        %{
          "id" => attachment.id,
          "type" => attachment.type,
          "string_original" => attachment.string_original,
          "string_preview" => attachment.string_preview,
          "position" => attachment.position,
          "inserted_at" => attachment.inserted_at,
          "updated_at" => attachment.updated_at
        }
      end
    )
  end

  def get_user(nil) do
    nil
  end

  def get_user(user) do
    %{
      "id" => user.id,
      "email" => user.email,
      "photo_original" => user.photo_original,
      "photo_preview" => user.photo_preview,
      "first_name" => user.first_name,
      "last_name" => user.last_name,
      "date_of_birth" => user.date_of_birth,
      "gender" => user.gender,
      "location" => user.location,
      "description" => user.description,
      "phone" => user.phone,
      "settings" => get_user_settings(user.settings)
    }
  end

  def get_user_settings(user_settings) do
    Enum.reduce(
      user_settings,
      %{},
      fn(user_setting, map) -> Map.merge(map, %{user_setting.key => user_setting.value === "True"}) end
    )
  end

  def get_user_status(nil) do
    nil
  end

  def get_user_status(user_status) do
    %{
      "id" => user_status.id,
      "string" => user_status.string,
      "title" => user_status.title,
      "url" => user_status.url,
      "notes" => user_status.notes,
      "attachments" => get_user_status_attachments(user_status.attachments)
    }
  end

  def get_user_status_attachments(attachments) do
    Enum.map(
      attachments,
      fn(attachment) ->
        %{
          "id" => attachment.id,
          "string_original" => attachment.string_original,
          "string_preview" => attachment.string_preview,
          "position" => attachment.position
        }
      end
    )
  end
end

defmodule WebSockets.Repo.Block do
  @moduledoc false

  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_blocks",
    do: (
      Schema.field(:timestamp, Ecto.DateTime)
      Schema.belongs_to(:user_source, WebSockets.Repo.User)
      Schema.belongs_to(:user_destination, WebSockets.Repo.User)
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
      Schema.belongs_to(:created_by, WebSockets.Repo.User)
      Schema.belongs_to(:owned_by, WebSockets.Repo.User)
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

      Schema.belongs_to(:user_destination, WebSockets.Repo.User)
      Schema.belongs_to(:user_source, WebSockets.Repo.User)
      Schema.belongs_to(:user_status, WebSockets.Repo.UserStatus)
      Schema.belongs_to(:master_tell, WebSockets.Repo.MasterTell)
      Schema.belongs_to(:post, WebSockets.Repo.Post)
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
      Schema.belongs_to(:message, WebSockets.Repo.Message)
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
      Schema.belongs_to(:user, WebSockets.Repo.User)
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
      Schema.belongs_to(:network, WebSockets.Repo.Network)
      Schema.belongs_to(:tellzone, WebSockets.Repo.Tellzone)
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
      Schema.belongs_to(:user, WebSockets.Repo.User)
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
      Schema.belongs_to(:user, WebSockets.Repo.User)
      Schema.belongs_to(:category, WebSockets.Repo.Category)
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
      Schema.belongs_to(:user_source, WebSockets.Repo.User)
      Schema.belongs_to(:user_destination, WebSockets.Repo.User)
      Schema.belongs_to(:network, WebSockets.Repo.Network)
      Schema.belongs_to(:tellzone, WebSockets.Repo.Tellzone)
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
      Schema.belongs_to(:user, WebSockets.Repo.User)
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
      Schema.belongs_to(:tellzone, WebSockets.Repo.Tellzone)
      Schema.has_many(:settings, WebSockets.Repo.UserSettings)
    )
  )
end

defmodule WebSockets.Repo.UserLocation do
  @moduledoc false

  @optional_fields ~w(
    user_id network_id tellzone_id location accuracies_horizontal accuracies_vertical bearing is_casting
  )
  @required_fields ~w(point)

  alias Ecto.Changeset, as: Changeset
  alias Ecto.DateTime, as: DateTime
  alias Ecto.Schema, as: Schema

  use Ecto.Schema

  Schema.schema(
    "api_users_locations",
    do: (
      Schema.field(:location, :string, default: "")
      Schema.field(:point, Geo.Point)
      Schema.field(:accuracies_horizontal, :float, default: 0.0)
      Schema.field(:accuracies_vertical, :float, default: 0.0)
      Schema.field(:bearing, :integer, default: 0)
      Schema.field(:is_casting, :boolean, default: true)
      Schema.field(:timestamp, Ecto.DateTime)
      Schema.belongs_to(:user, WebSockets.Repo.User)
      Schema.belongs_to(:network, WebSockets.Repo.Network)
      Schema.belongs_to(:tellzone, WebSockets.Repo.Tellzone)
    )
  )

  def changeset(user_location, parameters \\ :empty) do
    user_location
    |> Changeset.cast(parameters, @required_fields, @optional_fields)
    |> timestamp()
  end

  def timestamp(parameters) do
    Changeset.change(parameters, %{"timestamp": DateTime.utc()})
  end
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
      Schema.belongs_to(:user, WebSockets.Repo.User)
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
      Schema.belongs_to(:user, WebSockets.Repo.User)
      Schema.has_many(:attachments, WebSockets.Repo.UserStatusAttachments)
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
      Schema.belongs_to(:user_status, WebSockets.Repo.UserStatus)
    )
  )
end
