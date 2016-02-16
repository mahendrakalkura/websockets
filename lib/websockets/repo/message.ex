defmodule WebSockets.Repo.Message do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Query

  alias Ecto.Changeset, as: Changeset
  alias Ecto.DateTime, as: DateTime
  alias WebSockets.Repo, as: Repo
  alias WebSockets.Repo.Block, as: Block
  alias WebSockets.Repo.Message, as: Message

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

  schema "api_messages" do
    field :user_source_is_hidden, :boolean, default: false
    field :user_destination_is_hidden, :boolean, default: false
    field :type, :string
    field :contents, :string, default: ""
    field :status, :string, default: "Unread"
    field :is_suppressed, :boolean, default: false
    field :inserted_at, Ecto.DateTime
    field :updated_at, Ecto.DateTime
    belongs_to :user_destination, WebSockets.Repo.User
    belongs_to :user_source, WebSockets.Repo.User
    belongs_to :user_status, WebSockets.Repo.UserStatus
    belongs_to :master_tell, WebSockets.Repo.MasterTell
    belongs_to :post, WebSockets.Repo.Post
    has_many :attachments, WebSockets.Repo.MessageAttachment
  end

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
      |> select([message], count(message.id))
      |> where(
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
      |> where([message], is_nil(message.post_id))
      |> where([message], message.type in ["Response - Accepted", "Response - Rejected", "Message", "Ask"])
      |> Repo.one()
    ) do
      0 -> validate_type_2(parameters)
      _ -> Changeset.add_error(parameters, :user_destination_id, "Invalid `user_destination_id`")
    end
  end

  def validate_type_2(parameters) do
    case (
      Message
      |> select([message], message)
      |> where(
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
      |> where([message], is_nil(message.post_id))
      |> order_by(desc: :id)
      |> limit(1)
      |> offset(0)
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
      |> select([block], count(block.id))
      |> where(
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
