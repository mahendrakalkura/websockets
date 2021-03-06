defmodule WebSockets.Repo do
  @moduledoc false

  use Ecto.Repo, otp_app: :websockets

  import Ecto.Query

  alias Ecto.Date, as: Date
  alias Geo.JSON, as: JSON
  alias WebSockets.Repo, as: Repo
  alias WebSockets.Repo.MasterTellTellzone, as: MasterTellTellzone
  alias WebSockets.Utilities, as: Utilities

  require Poison

  def get_master_tell(nil), do: nil
  def get_master_tell(master_tell) do
    %{
      "id" => master_tell.id,
      "category_id" => master_tell.category_id,
      "created_by_id" => master_tell.created_by_id,
      "description" => master_tell.description,
      "owned_by_id" => master_tell.owned_by_id,
      "contents" => master_tell.contents,
      "position" => master_tell.position,
      "tellzone" => get_master_tell_tellzone(master_tell).tellzone |> get_tellzone,
      "is_visible" => master_tell.is_visible,
      "inserted_at" => Utilities.get_formatted_datetime(master_tell.inserted_at),
      "updated_at" => Utilities.get_formatted_datetime(master_tell.updated_at)
    }
  end

  def get_master_tell_tellzone([]), do: []
  def get_master_tell_tellzone(master_tell) do
    MasterTellTellzone
    |> select([master_tell_tellzone], master_tell_tellzone)
    |> where([master_tell_tellzone], master_tell_tellzone.master_tell_id == ^master_tell.id)
    |> Repo.one()
    |> Repo.preload(:tellzone)
  end

  def get_message(nil), do: nil
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
      "inserted_at" => Utilities.get_formatted_datetime(message.inserted_at),
      "updated_at" => Utilities.get_formatted_datetime(message.inserted_at),
      "attachments" => get_message_attachments(message.attachments)
    }
  end

  def get_message_attachments([]), do: []
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

  def get_notification(nil), do: nil
  def get_notification(notification) do
    %{
      "id" => notification.id,
      "user_id" => notification.user_id,
      "type" => notification.type,
      "contents" => elem(Poison.decode(notification.contents), 1),
      "status" => notification.status,
      "timestamp" => Utilities.get_formatted_datetime(notification.timestamp)
    }
  end

  def get_post(nil), do: nil
  def get_post(post) do
    %{
      "id" => post.id,
      "user_id" => post.user_id,
      "category_id" => post.category_id,
      "title" => post.title,
      "contents" => post.contents,
      "inserted_at" => Utilities.get_formatted_datetime(post.inserted_at),
      "updated_at" => Utilities.get_formatted_datetime(post.updated_at),
      "expired_at" => Utilities.get_formatted_datetime(post.expired_at),
      "attachments" => get_post_attachments(post.attachments)
    }
  end

  def get_post_attachments([]), do: []
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
          "inserted_at" => Utilities.get_formatted_datetime(attachment.inserted_at),
          "updated_at" => Utilities.get_formatted_datetime(attachment.updated_at)
        }
      end
    )
  end

  def get_tellzone([]), do: []
  def get_tellzone(tellzone) do
    %{
      "name" => tellzone.name,
      "photo" => tellzone.photo,
      "location" => tellzone.location,
      "phone" => tellzone.phone,
      "url" => tellzone.url,
      "hours" => elem(Poison.decode(tellzone.hours), 1),
      "point" => JSON.encode(tellzone.point),
      "inserted_at" => Utilities.get_formatted_datetime(tellzone.inserted_at),
      "updated_at" => Utilities.get_formatted_datetime(tellzone.updated_at),
      "status" => tellzone.status,
      "type" => tellzone.type,
      "user_id" => tellzone.user_id,
      "ended_at" => Utilities.get_formatted_datetime(tellzone.ended_at),
      "started_at" => Utilities.get_formatted_datetime(tellzone.started_at),
    }
  end

  def get_user(nil), do: nil
  def get_user(user) do
    %{
      "id" => user.id,
      "email" => user.email,
      "photo_original" => user.photo_original,
      "photo_preview" => user.photo_preview,
      "first_name" => user.first_name,
      "last_name" => user.last_name,
      "date_of_birth" => Date.to_string(user.date_of_birth),
      "gender" => user.gender,
      "location" => user.location,
      "description" => user.description,
      "phone" => user.phone,
      "settings" => get_user_settings(user.settings)
    }
  end

  def get_user_settings([]), do: %{}
  def get_user_settings(user_settings) do
    Enum.reduce(
      user_settings,
      %{},
      fn(user_setting, map) -> Map.merge(map, %{user_setting.key => user_setting.value === "True"}) end
    )
  end

  def get_user_status(nil), do: nil
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

  def get_user_status_attachments([]), do: []
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
