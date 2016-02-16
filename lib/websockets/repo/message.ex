defmodule WebSockets.Repo.Message do
  @moduledoc false

  use Ecto.Schema

  alias Ecto.Changeset, as: Changeset
  alias Ecto.DateTime, as: DateTime
  alias Ecto.Query, as: Query
  alias Ecto.Schema, as: Schema
  alias WebSockets.Repo, as: Repo
  alias WebSockets.Repo.Block, as: Block
  alias WebSockets.Repo.Message, as: Message

  require Ecto.Query

  @optional_fields ~w(
    user_status_id
    master_tell_id
    post_id
    user_source_is_hidden
    user_destination_is_hidden
    contents
    status
    is_suppressed
    inserted_at
    updated_at
  )
  @required_fields ~w(user_source_id user_destination_id type)

  Schema.schema(
    "api_messages",
    do: (
      Schema.field(:user_source_is_hidden, :boolean, default: false)
      Schema.field(:user_destination_is_hidden, :boolean, default: false)
      Schema.field(:type, :string)
      Schema.field(:contents, :string, default: "")
      Schema.field(:status, :string, default: "Unread")
      Schema.field(:is_suppressed, :boolean, default: false)
      Schema.field(:inserted_at, Ecto.DateTime)
      Schema.field(:updated_at, Ecto.DateTime)
      Schema.belongs_to(:user_destination, WebSockets.Repo.User)
      Schema.belongs_to(:user_source, WebSockets.Repo.User)
      Schema.belongs_to(:user_status, WebSockets.Repo.UserStatus)
      Schema.belongs_to(:master_tell, WebSockets.Repo.MasterTell)
      Schema.belongs_to(:post, WebSockets.Repo.Post)
      Schema.has_many(:attachments, WebSockets.Repo.MessageAttachment)
    )
  )

  def changeset(message, parameters \\ :empty) do
    message
    |> Changeset.cast(parameters, @required_fields, @optional_fields)
    |> Changeset.cast_assoc(:attachments, required: true)
    |> timestamp()
    |> validate_user_destination_id()
    |> validate_post_id()
    |> validate_blocks()
  end

  def timestamp(parameters) do
    Changeset.change(parameters, %{:inserted_at => DateTime.utc(), :updated_at => DateTime.utc()})
  end

  def validate_user_destination_id(parameters) do
    case parameters.changes.user_source_id === parameters.changes.user_destination_id do
      true -> Changeset.add_error(parameters, :user_destination_id, "Invalid `user_destination_id`")
      _ -> parameters
    end
  end

  def validate_post_id(parameters = %{"changes" => %{"post_id" => _}}) do
    case parameters.changes.post_id do
      nil -> validate_type_1(parameters)
      _ -> parameters
    end
  end

  def validate_post_id(parameters) do
    validate_type_1(parameters)
  end

  def validate_type_1(parameters) do
    case (
      Message
      |> Query.select([message], count(message.id))
      |> Query.where(
        [message],
        (
          message.user_source_id == ^parameters.changes.user_source_id
          and
          message.user_destination_id == ^parameters.changes.user_destination_id
        )
        or
        (
          message.user_source_id == ^parameters.changes.user_destination_id
          and
          message.user_destination_id == ^parameters.changes.user_source_id
        )
      )
      |> Query.where([message], is_nil(message.post_id))
      |> Query.where([message], message.type in ["Response - Accepted", "Response - Rejected", "Message", "Ask"])
      |> Repo.one()
    ) do
      0 -> validate_type_2(parameters)
      _ -> Changeset.add_error(parameters, :user_destination_id, "Invalid `user_destination_id`")
    end
  end

  def validate_type_2(parameters) do
    case (
      Message
      |> Query.select([message], message)
      |> Query.where(
        [message],
        (
          message.user_source_id == ^parameters.changes.user_source_id
          and
          message.user_destination_id == ^parameters.changes.user_destination_id
        )
        or
        (
          message.user_source_id == ^parameters.changes.user_destination_id
          and
          message.user_destination_id == ^parameters.changes.user_source_id
        )
      )
      |> Query.where([message], is_nil(message.post_id))
      |> Query.order_by(desc: :id)
      |> Query.limit(1)
      |> Query.offset(0)
      |> Repo.one()
    ) do
      nil -> validate_type_3(parameters)
      message -> validate_type_4(parameters, message)
    end
  end

  def validate_type_3(parameters) do
    case parameters.changes.type === "Request" do
      true -> parameters
      _ -> Changeset.add_error(parameters, :type, "HTTP_403_FORBIDDEN")
    end
  end

  def validate_type_4(parameters = %{"changes" => %{"type" => "Message"}}, message = %{:type => "Request"}) do
    if parameters.changes.user_source_id === message.user_destination_id do
      Changeset.add_error(parameters, :type, "HTTP_403_FORBIDDEN")
    else
      parameters
    end
  end

  def validate_type_4(parameters = %{"changes" => %{"type" => "Ask"}}, message = %{:type => "Request"}) do
    if parameters.changes.user_source_id === message.user_destination_id do
      Changeset.add_error(parameters, :type, "HTTP_403_FORBIDDEN")
    else
      parameters
    end
  end

  def validate_type_4(parameters, message = %{:type => "Request"}) do
    if parameters.changes.user_source_id === message.user_source_id do
      Changeset.add_error(parameters, :type, "HTTP_409_CONFLICT")
    else
      parameters
    end
  end

  def validate_type_4(parameters, %{:type => "Response - Blocked"}) do
    Changeset.add_error(parameters, :type, "HTTP_403_FORBIDDEN")
  end

  def validate_type_4(parameters, _message) do
    parameters
  end

  def validate_blocks(parameters) do
    case (
      Block
      |> Query.select([block], count(block.id))
      |> Query.where(
        [block],
        (
          block.user_source_id == ^parameters.changes.user_source_id
          and
          block.user_destination_id == ^parameters.changes.user_destination_id
        )
        or
        (
          block.user_source_id == ^parameters.changes.user_destination_id
          and
          block.user_destination_id == ^parameters.changes.user_source_id
        )
      )
      |> Repo.one()
    ) do
      0 -> parameters
      _ -> Changeset.add_error(parameters, :user_destination_id, "Invalid `user_destination_id`")
    end
  end
end
