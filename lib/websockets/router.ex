defmodule WebSockets.Router do
  @moduledoc false

  @behaviour :cowboy_websocket_handler

  alias AMQP.Basic, as: Basic
  alias AMQP.Channel, as: Channel
  alias AMQP.Connection, as: Connection
  alias Comeonin.Bcrypt, as: Bcrypt
  alias ExJsonSchema.Schema, as: Schema
  alias ExJsonSchema.Validator, as: Validator
  alias WebSockets.Clients, as: Clients
  alias WebSockets.Repo, as: Repo
  alias WebSockets.Repo.Block, as: Block
  alias WebSockets.Repo.Message, as: Message
  alias WebSockets.Repo.User, as: User
  alias WebSockets.Repo.UserLocation, as: UserLocation
  alias WebSockets.Utilities, as: Utilities

  require Application
  require Integer
  require JSX
  require Kernel
  require Map
  require String
  require WebSockets

  def init(_protocol, _request, _options) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_protocol, request, _options) do
    {:ok, request, :undefined_state}
  end

  def websocket_handle({:text, "ping"}, request, state) do
    pid = Kernel.self()
    Kernel.spawn(fn() -> Utilities.log("Router", "In", pid, "ping") end)
    Kernel.spawn(fn() -> Utilities.log("Router", "Out", pid, "pong") end)
    {:reply, {:text, "pong"}, request, state}
  end

  def websocket_handle({:text, "pong"}, request, state) do
    pid = Kernel.self()
    Kernel.spawn(fn() -> Utilities.log("Router", "In", pid, "pong") end)
    Kernel.spawn(fn() -> Utilities.log("Router", "Out", pid, "ping") end)
    {:reply, {:text, "ping"}, request, state}
  end

  def websocket_handle({:text, contents}, request, state) do
    pid = Kernel.self()
    case JSX.decode(contents) do
      {:ok, %{"subject" => subject, "body" => body}} ->
        Kernel.spawn(fn() -> handle(pid, subject, body) end)
      {:ok, _} ->
        Kernel.spawn(fn() -> Utilities.log("websocket_handle()", %{"contents" => contents}) end)
      {:error, reason} ->
        Kernel.spawn(fn() -> Utilities.log("websocket_handle()", %{"contents" => contents, "reason" => reason}) end)
    end
    {:ok, request, state}
  end

  def websocket_info({subject, body, action}, request, state) do
    pid = Kernel.self()
    Kernel.spawn(fn() -> Utilities.log("Router", "Out", pid, subject) end)
    {:ok, message} = JSX.encode(%{"subject" => subject, "body" => body, "action" => action})
    {:reply, {:text, message}, request, state}
  end

  def websocket_info({subject, body}, request, state) do
    pid = Kernel.self()
    Kernel.spawn(fn() -> Utilities.log("Router", "Out", pid, subject) end)
    {:ok, message} = JSX.encode(%{"subject" => subject, "body" => body})
    {:reply, {:text, message}, request, state}
  end

  def websocket_info(contents, request, state) do
    Kernel.spawn(fn() -> Utilities.log("websocket_info()", %{"contents" => contents}) end)
    {:ok, request, state}
  end

  def websocket_terminate(reason, _request, _state) do
    pid = Kernel.self()
    Kernel.spawn(fn() -> Clients.delete(pid) end)
    Kernel.spawn(fn() -> terminate(reason) end)
    :ok
  end

  def handle(pid, "messages", body) do
    Kernel.spawn(fn() -> Utilities.log("Router", "In", pid, "messages") end)
    Kernel.spawn(fn() -> messages_1(pid, body) end)
  end

  def handle(pid, "users", body) do
    Kernel.spawn(fn() -> Utilities.log("Router", "In", pid, "users") end)
    Kernel.spawn(fn() -> users_1(pid, body) end)
  end

  def handle(pid, "users_locations_post", body) do
    Kernel.spawn(fn() -> Utilities.log("Router", "In", pid, "users_locations_post") end)
    Kernel.spawn(fn() -> users_locations_post_1(pid, body) end)
  end

  def handle(_pid, subject, body) do
    Kernel.spawn(fn() -> Utilities.log("handle()", %{"subject" => subject, "body" => body}) end)
  end

  def terminate({:error, :closed}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:error, :closed}"}) end)
  end

  def terminate({:error, :badencoding}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:error, :badencoding}"}) end)
  end

  def terminate({:error, :badframe}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:error, :badframe}"}) end)
  end

  def terminate({:error, atom}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:error, #{atom}}"}) end)
  end

  def terminate({:normal, :shutdown}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:normal, :shutdown}"}) end)
  end

  def terminate({:normal, :timeout}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:normal, :timeout}"}) end)
  end

  def terminate({:remote, :closed}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:remote, :closed}"}) end)
  end

  def terminate({:remote, prefix, suffix}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => %{"prefix" => prefix, "suffix" => suffix}}) end)
  end

  def terminate(_) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "_"}) end)
  end

  def messages_1(pid, body) do
    case Utilities.get_id(pid) do
      0 -> Kernel.send(pid, {"messages", %{"body" => %{"errors" => "Invalid User"}}})
      id -> Kernel.spawn(fn() -> messages_2(pid, id, body) end)
    end
  end

  def messages_2(pid, id, body) do
    schema = Schema.resolve(%{
      "properties" => %{
        "user_source_is_hidden" => %{"type" => "boolean"},
        "user_destination_id" => %{"type" => "integer"},
        "user_destination_is_hidden" => %{"type" => "boolean"},
        "user_status_id" => %{"type" => "integer"},
        "master_tell_id" => %{"type" => "integer"},
        "post_id" => %{"type" => "integer"},
        "type" => %{
          "enum" => ["Ask", "Message", "Request", "Response - Accepted", "Response - Blocked", "Response - Rejected"]
        },
        "contents" => %{"type" => "string"},
        "status" => %{"enum" => ["Unread", "Read"]},
        "attachments" => %{
          "type" => "array",
          "items" => %{
            "properties" => %{
              "string" => %{"type" => "string"},
              "position" => %{"type" => "integer"},
            },
            "required" => ["string", "position"],
            "type" => "object"
          },
          "minItems" => 0
        }
      },
      "required" => ["user_destination_id", "type", "status"],
      "type" => "object"
    })
    case Validator.validate(schema, body) do
      {:error, errors} ->
        Kernel.send(pid, {"messages", %{"body" => %{"errors" => errors}}})
      :ok ->
        Kernel.spawn(fn() -> messages_3(pid, id, body) end)
    end
  end

  def messages_3(pid, id, body) do
    changeset = Message.changeset(%Message{}, Map.merge(body, %{"user_source_id" => id}))
    case changeset.valid? do
      false ->
        Kernel.spawn(
          fn() ->
            Utilities.log(
              "messages_3()",
              %{"changeset" => %{"params" => changeset.params, "errors" => changeset.errors}}
            )
          end
        )
        Kernel.send(pid, {"messages", %{"body" => %{"errors" => changeset.errors}}})
      _ ->
        Kernel.spawn(fn() -> messages_4(pid, changeset) end)
    end
  end

  def messages_4(pid, changeset) do
    case Repo.insert(changeset) do
      {:ok, message} ->
        Kernel.spawn(
          fn() ->
            {:ok, connection} = Connection.open(Application.get_env(:websockets, :broker))
            {:ok, channel} = Channel.open(connection)
            Basic.publish(
              channel,
              WebSockets.get_exchange(),
              WebSockets.get_routing_key(),
              "{\"subject\":\"messages\",\"body\":\"#{message.id}\"}"
            )
          end
        )
        Kernel.spawn(fn() -> messages_5(message) end)
      {:error, changeset} ->
        Kernel.spawn(
          fn() ->
            Utilities.log(
              "messages_4()",
              %{"changeset" => %{"params" => changeset.params, "errors" => changeset.errors}}
            )
          end
        )
        Kernel.send(pid, {"messages", %{"body" => %{"errors" => "Invalid Body"}}})
    end
  end

  def messages_5(message = %{:type => "Response - Blocked"}) do
    case message do
      %{:type => "Response - Rejected"} ->
        Kernel.spawn(fn() -> messages_6(message) end)
      %{:type => "Response - Blocked"} ->
        Kernel.spawn(fn() -> messages_6(message) end)
        Kernel.spawn(fn() -> messages_7(message) end)
      _ -> nil
    end
    Kernel.spawn(fn() -> messages_9(message) end)
  end

  def messages_6(message) do
    ids = [message.id]
    case SQL.query(
      Repo,
      """
      SELECT id
      FROM messages
      WHERE
        (
          id < $1
          (
            (user_source_id = $2 AND user_destination_id = $3)
            OR
            (user_source_id = $3 AND user_destination_id = $2)
          )
          AND
          type = $4
        )
      """,
      [message.id, message.user_source_id, message.user_destination_id, "Request"],
      []
    ) do
      {:ok, %{rows: rows, num_rows: 1}} -> ids = ids ++ [Enum.at(Enum.at(rows, 0))]
      {:error, exception} -> Kernel.spawn(fn() -> Utilities.log("messages_6()", %{"exception" => exception}) end)
    end
    case SQL.query(Repo, "UPDATE api_messages SET is_suppressed = $1 WHERE id = ANY($2)", [true, ids], []) do
      {:ok, _} -> nil
      {:error, exception} -> Kernel.spawn(fn() -> Utilities.log("messages_6()", %{"exception" => exception}) end)
    end
  end

  def messages_7(message) do
    changeset = Block.changeset(
      %Block{}, %{"user_source_id" => message.user_source_id, "user_destination_id" => message.user_destination_id}
    )
    case changeset.valid? do
      false ->
        Kernel.spawn(
          fn() ->
            Utilities.log(
              "messages_7()",
              %{"changeset" => %{"params" => changeset.params, "errors" => changeset.errors}}
            )
          end
        )
      _ -> Kernel.spawn(fn() -> messages_8(changeset) end)
    end
  end

  def messages_8(changeset) do
    case Repo.insert(changeset) do
      {:ok, block} ->
        Kernel.spawn(
          fn() ->
            {:ok, connection} = Connection.open(Application.get_env(:websockets, :broker))
            {:ok, channel} = Channel.open(connection)
            Basic.publish(
              channel,
              WebSockets.get_exchange(),
              WebSockets.get_routing_key(),
              "{\"subject\":\"blocks\",\"body\":\"#{block.id}\"}"
            )
          end
        )
      {:error, changeset} ->
        Kernel.spawn(
          fn() ->
            Utilities.log(
              "messages_7()",
              %{"changeset" => %{"params" => changeset.params, "errors" => changeset.errors}}
            )
          end
        )
    end
  end

  def messages_9(message = %{:type => "Request"}) do
    case SQL.query(
      Repo,
      "SELECT COUNT(id) FROM api_users_settings WHERE user_id = $1 AND key = $2 AND value = $3",
      [message.user_destination_id, "notifications_invitations", "True"],
      []
    ) do
      {:ok, %{rows: [[0]], num_rows: 1}} -> Kernel.spawn(fn() -> messages_10(message) end)
      {:ok, _} -> nil
      {:error, exception} -> Kernel.spawn(fn() -> Utilities.log("messages_6()", %{"exception" => exception}) end)
    end
  end

  def messages_9(message = %{:type => "Response - Accepted"}) do
    case SQL.query(
      Repo,
      "SELECT COUNT(id) FROM api_users_settings WHERE user_id = $1 AND key = $2 AND value = $3",
      [message.user_destination_id, "notifications_invitations", "True"],
      []
    ) do
      {:ok, %{rows: [[0]], num_rows: 1}} -> Kernel.spawn(fn() -> messages_10(message) end)
      {:ok, _} -> nil
      {:error, exception} -> Kernel.spawn(fn() -> Utilities.log("messages_6()", %{"exception" => exception}) end)
    end
  end

  def messages_9(message = %{:type => "Message"}) do
    case SQL.query(
      Repo,
      "SELECT COUNT(id) FROM api_users_settings WHERE user_id = $1 AND key = $2 AND value = $3",
      [message.user_destination_id, "notifications_messages", "True"],
      []
    ) do
      {:ok, %{rows: [[0]], num_rows: 1}} -> Kernel.spawn(fn() -> messages_10(message) end)
      {:ok, _} -> nil
      {:error, exception} -> Kernel.spawn(fn() -> Utilities.log("messages_6()", %{"exception" => exception}) end)
    end
  end

  def messages_9(message = %{:type => "Ask"}) do
    case SQL.query(
      Repo,
      "SELECT COUNT(id) FROM api_users_settings WHERE user_id = $1 AND key = $2 AND value = $3",
      [message.user_destination_id, "notifications_messages", "True"],
      []
    ) do
      {:ok, %{rows: [[0]], num_rows: 1}} -> Kernel.spawn(fn() -> messages_10(message) end)
      {:ok, _} -> nil
      {:error, exception} -> Kernel.spawn(fn() -> Utilities.log("messages_6()", %{"exception" => exception}) end)
    end
  end

  def messages_10(message) do
    contents = {
      message.user_destination_id,
      %{
        "aps" => %{
          "alert" => %{
            "title" => "New message from user",
            "body" => message.contents
          },
          "badge" => 0
        },
        "type" => "message",
        "user_source_id" => message.user_source_id,
        "post_id" => message.post_id
      }
    }
    case JSX.encode(contents) do
      {:ok, contents} ->
        Kernel.spawn(
          fn() ->
            {:ok, connection} = Connection.open(Application.get_env(:websockets, :broker))
            {:ok, channel} = Channel.open(connection)
            Basic.publish(channel, "api.tasks.push_notifications", "api.tasks.push_notifications", contents)
          end
        )
      {:error, reason} ->
        Kernel.spawn(fn() -> Utilities.log("messages_10()", %{"contents" => contents, "reason" => reason}) end)
    end
  end

  def users_1(pid, token) do
    case String.split(token, Application.get_env(:websockets, :separator), parts: 2, trim: true) do
      [id, hash] ->
        Kernel.spawn(fn() -> users_2(pid, id, hash) end)
      _ ->
        Kernel.send(pid, {"users", false})
    end
  end

  def users_2(pid, id, hash) do
    if Bcrypt.checkpw(id <> Application.get_env(:websockets, :secret), hash) do
      Kernel.spawn(fn() -> users_3(pid, id) end)
    else
      Kernel.send(pid, {"users", false})
    end
  end

  def users_3(pid, id) do
    case Integer.parse(id) do
      {id, _} ->
        Kernel.spawn(fn() -> users_4(pid, id) end)
      _ ->
        Kernel.send(pid, {"users", false})
    end
  end

  def users_4(pid, id) do
    case Repo.get(User, id) do
      nil ->
        Kernel.send(pid, {"users", false})
      user ->
        Kernel.spawn(fn() -> Clients.insert(pid, user.id) end)
        Kernel.send(pid, {"users", true})
    end
  end

  def users_locations_post_1(pid, body) do
    case Utilities.get_id(pid) do
      0 ->
        Kernel.send(pid, {"users_locations", %{"body" => %{"errors" => "Invalid User"}}})
      id ->
        users_locations_post_2(pid, id, body)
    end
  end

  def users_locations_post_2(pid, id, body) do
    schema = Schema.resolve(%{
      "properties" => %{
        "network_id" => %{"type" => "integer"},
        "tellzone_id" => %{"type" => "integer"},
        "location" => %{"type" => "string"},
        "point" => %{
          "properties" => %{"longitude" => %{"type" => "number"}, "latitude" => %{"type" => "number"}},
          "required" => ["longitude", "latitude"],
          "type" => "object"
        },
        "accuracies_horizontal" => %{"type" => "number"},
        "accuracies_vertical" => %{"type" => "number"},
        "bearing" => %{"type" => "integer"},
        "is_casting" => %{"type" => "boolean"}
      },
      "required" => ["point"],
      "type" => "object"
    })
    case Validator.validate(schema, body) do
      {:error, errors} ->
        Kernel.send(pid, {"users_locations", %{"body" => %{"errors" => errors}}})
      :ok ->
        Kernel.spawn(fn() -> users_locations_post_3(pid, id, body) end)
    end
  end

  def users_locations_post_3(pid, id, body) do
    changeset = UserLocation.changeset(
      %UserLocation{}, Map.merge(body, %{"user_id" => id, "point" => Utilities.get_point(body["point"])})
    )
    case changeset.valid? do
      false ->
        Kernel.spawn(
          fn() ->
            Utilities.log(
              "users_locations_post_3()",
              %{"changeset" => %{"params" => changeset.params, "errors" => changeset.errors}}
            )
          end
        )
        Kernel.send(pid, {"users_locations", %{"body" => %{"errors" => changeset.errors}}})
      _ ->
        Kernel.spawn(fn() -> users_locations_post_4(pid, changeset) end)
    end
  end

  def users_locations_post_4(pid, changeset) do
    case Repo.insert(changeset) do
      {:ok, user_location} ->
        Kernel.spawn(
          fn() ->
            {:ok, connection} = Connection.open(Application.get_env(:websockets, :broker))
            {:ok, channel} = Channel.open(connection)
            Basic.publish(
              channel,
              WebSockets.get_exchange(),
              WebSockets.get_routing_key(),
              "{\"subject\":\"users_locations\",\"body\":\"#{user_location.id}\"}"
            )
          end
        )
      {:error, changeset} ->
        Kernel.spawn(
          fn() ->
            Utilities.log(
              "users_locations_post_4()",
              %{"changeset" => %{"params" => changeset.params, "errors" => changeset.errors}}
            )
          end
        )
        Kernel.send(pid, {"users_locations", %{"body" => %{"errors" => "Invalid Body"}}})
    end
  end
end
