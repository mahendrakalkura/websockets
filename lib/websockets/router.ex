defmodule WebSockets.Router do
  @moduledoc false

  alias Comeonin.Bcrypt, as: Bcrypt
  alias Ecto.Adapters.SQL, as: SQL
  alias ExJsonSchema.Schema, as: Schema
  alias ExJsonSchema.Validator, as: Validator
  alias WebSockets.Clients, as: Clients
  alias WebSockets.Repo, as: Repo
  alias WebSockets.Repo.Block, as: Block
  alias WebSockets.Repo.Message, as: Message
  alias WebSockets.Repo.User, as: User
  alias WebSockets.Repo.UserLocation, as: UserLocation
  alias WebSockets.Utilities, as: Utilities

  require JSX
  require WebSockets

  @behaviour :cowboy_websocket_handler

  def init(_protocol, _request, _options) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_protocol, request, _options) do
    {:ok, request, :undefined_state}
  end

  def websocket_handle({:text, "ping"}, request, state) do
    pid = self()
    spawn(fn() -> Utilities.log("Router", "In", pid, "ping") end)
    spawn(fn() -> Utilities.log("Router", "Out", pid, "pong") end)
    {:reply, {:text, "pong"}, request, state}
  end

  def websocket_handle({:text, "pong"}, request, state) do
    pid = self()
    spawn(fn() -> Utilities.log("Router", "In", pid, "pong") end)
    spawn(fn() -> Utilities.log("Router", "Out", pid, "ping") end)
    {:reply, {:text, "ping"}, request, state}
  end

  def websocket_handle({:text, contents}, request, state) do
    pid = self()
    case JSX.decode(contents) do
      {:ok, %{"subject" => subject, "body" => body}} ->
        spawn(fn() -> handle(pid, subject, body) end)
      {:ok, _} ->
        spawn(fn() -> Utilities.log("websocket_handle()", %{"contents" => contents}) end)
      {:error, reason} ->
        spawn(fn() -> Utilities.log("websocket_handle()", %{"contents" => contents, "reason" => reason}) end)
    end
    {:ok, request, state}
  end

  def websocket_info({subject, body, action}, request, state) do
    pid = self()
    spawn(fn() -> Utilities.log("Router", "Out", pid, subject) end)
    {:ok, message} = JSX.encode(%{"subject" => subject, "body" => body, "action" => action})
    {:reply, {:text, message}, request, state}
  end

  def websocket_info({subject, body}, request, state) do
    pid = self()
    spawn(fn() -> Utilities.log("Router", "Out", pid, subject) end)
    {:ok, message} = JSX.encode(%{"subject" => subject, "body" => body})
    {:reply, {:text, message}, request, state}
  end

  def websocket_info(contents, request, state) do
    spawn(fn() -> Utilities.log("websocket_info()", %{"contents" => contents}) end)
    {:ok, request, state}
  end

  def websocket_terminate(reason, _request, _state) do
    pid = self()
    spawn(fn() -> Clients.delete(pid) end)
    spawn(fn() -> terminate(reason) end)
    :ok
  end

  def handle(pid, "messages", body) do
    spawn(fn() -> Utilities.log("Router", "In", pid, "messages") end)
    spawn(fn() -> messages_1(pid, body) end)
  end

  def handle(pid, "users", body) do
    spawn(fn() -> Utilities.log("Router", "In", pid, "users") end)
    spawn(fn() -> users_1(pid, body) end)
  end

  def handle(pid, "users_locations_post", body) do
    spawn(fn() -> Utilities.log("Router", "In", pid, "users_locations_post") end)
    spawn(fn() -> users_locations_post_1(pid, body) end)
  end

  def handle(_pid, subject, body) do
    spawn(fn() -> Utilities.log("handle()", %{"subject" => subject, "body" => body}) end)
  end

  def terminate({:error, :closed}) do
    spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:error, :closed}"}) end)
  end

  def terminate({:error, :badencoding}) do
    spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:error, :badencoding}"}) end)
  end

  def terminate({:error, :badframe}) do
    spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:error, :badframe}"}) end)
  end

  def terminate({:error, atom}) do
    spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:error, #{atom}}"}) end)
  end

  def terminate({:normal, :shutdown}) do
    spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:normal, :shutdown}"}) end)
  end

  def terminate({:normal, :timeout}) do
    spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:normal, :timeout}"}) end)
  end

  def terminate({:remote, :closed}) do
    spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:remote, :closed}"}) end)
  end

  def terminate({:remote, prefix, suffix}) do
    spawn(fn() -> Utilities.log("terminate()", %{"reason" => %{"prefix" => prefix, "suffix" => suffix}}) end)
  end

  def terminate(_) do
    spawn(fn() -> Utilities.log("terminate()", %{"reason" => "_"}) end)
  end

  def messages_1(pid, body) do
    case Utilities.get_id(pid) do
      0 -> send(pid, {"messages", %{"body" => %{"errors" => "Invalid User"}}})
      id -> spawn(fn() -> messages_2(pid, id, body) end)
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
        send(pid, {"messages", %{"body" => %{"errors" => errors}}})
      :ok ->
        spawn(fn() -> messages_3(pid, id, body) end)
    end
  end

  def messages_3(pid, id, body) do
    changeset = Message.changeset(%Message{}, Map.merge(body, %{"user_source_id" => id}))
    case changeset.valid? do
      false ->
        spawn(
          fn() ->
            Utilities.log(
              "messages_3()",
              %{"changeset" => %{"params" => changeset.params, "errors" => changeset.errors}}
            )
          end
        )
        send(pid, {"messages", %{"body" => %{"errors" => changeset.errors}}})
      _ ->
        spawn(fn() -> messages_4(pid, changeset) end)
    end
  end

  def messages_4(pid, changeset) do
    case Repo.insert(changeset) do
      {:ok, message} ->
        spawn(
          fn() ->
            Utilities.publish(
              WebSockets.get_exchange(:websockets),
              WebSockets.get_routing_key(:websockets),
              %{"subject" => "messages", "body" => message.id}
            )
          end
        )
        spawn(fn() -> messages_5(message) end)
      {:error, changeset} ->
        spawn(
          fn() ->
            Utilities.log(
              "messages_4()",
              %{"changeset" => %{"params" => changeset.params, "errors" => changeset.errors}}
            )
          end
        )
        send(pid, {"messages", %{"body" => %{"errors" => "Invalid Body"}}})
    end
  end

  def messages_5(message = %{:type => "Response - Blocked"}) do
    case message do
      %{:type => "Response - Rejected"} ->
        spawn(fn() -> messages_6(message) end)
      %{:type => "Response - Blocked"} ->
        spawn(fn() -> messages_6(message) end)
        spawn(fn() -> messages_7(message) end)
      _ -> nil
    end
    spawn(fn() -> messages_9(message) end)
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
      {:error, exception} -> spawn(fn() -> Utilities.log("messages_6()", %{"exception" => exception}) end)
    end
    case SQL.query(Repo, "UPDATE api_messages SET is_suppressed = $1 WHERE id = ANY($2)", [true, ids], []) do
      {:ok, _} -> nil
      {:error, exception} -> spawn(fn() -> Utilities.log("messages_6()", %{"exception" => exception}) end)
    end
  end

  def messages_7(message) do
    changeset = Block.changeset(
      %Block{}, %{"user_source_id" => message.user_source_id, "user_destination_id" => message.user_destination_id}
    )
    case changeset.valid? do
      false ->
        spawn(
          fn() ->
            Utilities.log(
              "messages_7()",
              %{"changeset" => %{"params" => changeset.params, "errors" => changeset.errors}}
            )
          end
        )
      _ -> spawn(fn() -> messages_8(changeset) end)
    end
  end

  def messages_8(changeset) do
    case Repo.insert(changeset) do
      {:ok, block} ->
        spawn(
          fn() ->
            Utilities.publish(
              WebSockets.get_exchange(:websockets),
              WebSockets.get_routing_key(:websockets),
              %{"subject" => "blocks", "body" => block.id}
            )
          end
        )
      {:error, changeset} ->
        spawn(
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
      {:ok, %{rows: [[0]], num_rows: 1}} ->
        Utilities.publish(
          "api.tasks.push_notifications",
          "api.tasks.push_notifications",
          {
            message.user_destination_id,
            %{
              "aps" => %{
                "alert" => %{
                  "title" => "New message from user",
                  "body" => message.contents # REVIEW
                },
                "badge" => 0 # REVIEW
              },
              "type" => "message",
              "user_source_id" => message.user_source_id,
              "post_id" => message.post_id
            }
          }
        )
      {:ok, _} -> nil
      {:error, exception} -> spawn(fn() -> Utilities.log("messages_6()", %{"exception" => exception}) end)
    end
  end

  def messages_9(message = %{:type => "Response - Accepted"}) do
    case SQL.query(
      Repo,
      "SELECT COUNT(id) FROM api_users_settings WHERE user_id = $1 AND key = $2 AND value = $3",
      [message.user_destination_id, "notifications_invitations", "True"],
      []
    ) do
      {:ok, %{rows: [[0]], num_rows: 1}} ->
        Utilities.publish(
          "api.tasks.push_notifications",
          "api.tasks.push_notifications",
          {
            message.user_destination_id,
            %{
              "aps" => %{
                "alert" => %{
                  "title" => "New message from user",
                  "body" => message.contents # REVIEW
                },
                "badge" => 0 # REVIEW
              },
              "type" => "message",
              "user_source_id" => message.user_source_id,
              "post_id" => message.post_id
            }
          }
        )
      {:ok, _} -> nil
      {:error, exception} -> spawn(fn() -> Utilities.log("messages_6()", %{"exception" => exception}) end)
    end
  end

  def messages_9(message = %{:type => "Message"}) do
    case SQL.query(
      Repo,
      "SELECT COUNT(id) FROM api_users_settings WHERE user_id = $1 AND key = $2 AND value = $3",
      [message.user_destination_id, "notifications_messages", "True"],
      []
    ) do
      {:ok, %{rows: [[0]], num_rows: 1}} ->
        Utilities.publish(
          "api.tasks.push_notifications",
          "api.tasks.push_notifications",
          {
            message.user_destination_id,
            %{
              "aps" => %{
                "alert" => %{
                  "title" => "New message from user",
                  "body" => message.contents # REVIEW
                },
                "badge" => 0 # REVIEW
              },
              "type" => "message",
              "user_source_id" => message.user_source_id,
              "post_id" => message.post_id
            }
          }
        )
      {:ok, _} -> nil
      {:error, exception} -> spawn(fn() -> Utilities.log("messages_6()", %{"exception" => exception}) end)
    end
  end

  def messages_9(message = %{:type => "Ask"}) do
    case SQL.query(
      Repo,
      "SELECT COUNT(id) FROM api_users_settings WHERE user_id = $1 AND key = $2 AND value = $3",
      [message.user_destination_id, "notifications_messages", "True"],
      []
    ) do
      {:ok, %{rows: [[0]], num_rows: 1}} ->
        Utilities.publish(
          "api.tasks.push_notifications",
          "api.tasks.push_notifications",
          {
            message.user_destination_id,
            %{
              "aps" => %{
                "alert" => %{
                  "title" => "New message from user",
                  "body" => message.contents # REVIEW
                },
                "badge" => 0 # REVIEW
              },
              "type" => "message",
              "user_source_id" => message.user_source_id,
              "post_id" => message.post_id
            }
          }
        )
      {:ok, _} -> nil
      {:error, exception} -> spawn(fn() -> Utilities.log("messages_9()", %{"exception" => exception}) end)
    end
  end

  def users_1(pid, token) do
    case String.split(token, Application.get_env(:websockets, :separator), parts: 2, trim: true) do
      [id, hash] ->
        spawn(fn() -> users_2(pid, id, hash) end)
      _ ->
        send(pid, {"users", false})
    end
  end

  def users_2(pid, id, hash) do
    if Bcrypt.checkpw(id <> Application.get_env(:websockets, :secret), hash) do
      spawn(fn() -> users_3(pid, id) end)
    else
      send(pid, {"users", false})
    end
  end

  def users_3(pid, id) do
    case Integer.parse(id) do
      {id, _} ->
        spawn(fn() -> users_4(pid, id) end)
      _ ->
        send(pid, {"users", false})
    end
  end

  def users_4(pid, id) do
    case Repo.get(User, id) do
      nil ->
        send(pid, {"users", false})
      user ->
        spawn(fn() -> Clients.insert(pid, user.id) end)
        send(pid, {"users", true})
    end
  end

  def users_locations_post_1(pid, body) do
    case Utilities.get_id(pid) do
      0 ->
        send(pid, {"users_locations", %{"body" => %{"errors" => "Invalid User"}}})
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
        send(pid, {"users_locations", %{"body" => %{"errors" => errors}}})
      :ok ->
        spawn(fn() -> users_locations_post_3(pid, id, body) end)
    end
  end

  def users_locations_post_3(pid, id, body) do
    changeset = UserLocation.changeset(
      %UserLocation{}, Map.merge(body, %{"user_id" => id, "point" => Utilities.get_point(body["point"])})
    )
    case changeset.valid? do
      false ->
        spawn(
          fn() ->
            Utilities.log(
              "users_locations_post_3()",
              %{"changeset" => %{"params" => changeset.params, "errors" => changeset.errors}}
            )
          end
        )
        send(pid, {"users_locations", %{"body" => %{"errors" => changeset.errors}}})
      _ ->
        spawn(fn() -> users_locations_post_4(pid, changeset) end)
    end
  end

  def users_locations_post_4(pid, changeset) do
    case Repo.insert(changeset) do
      {:ok, user_location} ->
        spawn(
          fn() ->
            Utilities.publish(
              WebSockets.get_exchange(:websockets),
              WebSockets.get_routing_key(:websockets),
              %{"subject" => "users_locations", "body" => user_location.id}
            )
          end
        )
      {:error, changeset} ->
        spawn(
          fn() ->
            Utilities.log(
              "users_locations_post_4()",
              %{"changeset" => %{"params" => changeset.params, "errors" => changeset.errors}}
            )
          end
        )
        send(pid, {"users_locations", %{"body" => %{"errors" => "Invalid Body"}}})
    end
  end
end
