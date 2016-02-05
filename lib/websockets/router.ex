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
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "In", id, "ping") end)
    Kernel.spawn(fn() -> Utilities.log("Router", "Out", id, "pong") end)
    {:reply, {:text, "pong"}, request, state}
  end

  def websocket_handle({:text, "pong"}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "In", id, "pong") end)
    Kernel.spawn(fn() -> Utilities.log("Router", "Out", id, "ping") end)
    {:reply, {:text, "ping"}, request, state}
  end

  def websocket_handle({:text, contents}, request, state) do
    case JSX.decode(contents) do
      {:ok, %{"subject" => subject, "body" => body}} ->
        handle(subject, body, request, state)
      {:ok, _} ->
        Kernel.spawn(fn() -> Utilities.log("websocket_handle()", %{"contents" => contents}) end)
        {:ok, request, state}
      {:error, reason} ->
        Kernel.spawn(fn() -> Utilities.log("websocket_handle()", %{"contents" => contents, "reason" => reason}) end)
        {:ok, request, state}
    end
  end

  def websocket_info({subject, body, action}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "Out", id, subject) end)
    {:ok, message} = JSX.encode(%{"subject" => subject, "body" => body, "action" => action})
    {:reply, {:text, message}, request, state}
  end

  def websocket_info({subject, body}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "Out", id, subject) end)
    {:ok, message} = JSX.encode(%{"subject" => subject, "body" => body})
    {:reply, {:text, message}, request, state}
  end

  def websocket_info(contents, request, state) do
    Kernel.spawn(fn() -> Utilities.log("websocket_info()", %{"contents" => contents}) end)
    {:ok, request, state}
  end

  def websocket_terminate(reason, _request, _state) do
    Clients.delete(Kernel.self())
    terminate(reason)
    :ok
  end

  def handle("messages", body, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "In", id, "messages") end)
    messages_1(id, body, request, state)
  end

  def handle("users", body, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "In", id, "users") end)
    users_1(body, request, state)
  end

  def handle("users_locations_post", body, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "In", id, "users_locations_post") end)
    users_locations_post_1(id, body, request, state)
    {:ok, request, state}
  end

  def handle(subject, body, request, state) do
    Kernel.spawn(fn() -> Utilities.log("handle()", %{"subject" => subject, "body" => body}) end)
    {:ok, request, state}
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

  def messages_1(id, _body, request, state) do
    case id do
      0 ->
        Kernel.send(Kernel.self(), {"messages", %{"body" => %{"errors" => "Invalid User"}}})
        {:ok, request, state}
      _id ->
        # TODO
        {:ok, request, state}
    end
  end

  def users_1(token, request, state) do
    case String.split(token, Application.get_env(:websockets, :separator), parts: 2, trim: true) do
      [id, hash] ->
        users_2(id, hash, request, state)
      _ ->
        Kernel.send(Kernel.self(), {"users", false})
        {:ok, request, state}
    end
  end

  def users_2(id, hash, request, state) do
    if Bcrypt.checkpw(id <> Application.get_env(:websockets, :secret), hash) do
      users_3(id, request, state)
    else
      Kernel.send(Kernel.self(), {"users", false})
      {:ok, request, state}
    end
  end

  def users_3(id, request, state) do
    case Integer.parse(id) do
      {id, _} ->
        users_4(id, request, state)
      _ ->
        Kernel.send(Kernel.self(), {"users", false})
        {:ok, request, state}
    end
  end

  def users_4(id, request, state) do
    case Repo.get(User, id) do
      nil ->
        Kernel.send(Kernel.self(), {"users", false})
        {:ok, request, state}
      user ->
        Clients.insert(Kernel.self(), user.id)
        Kernel.send(Kernel.self(), {"users", true})
        {:ok, request, state}
    end
  end

  def users_locations_post_1(id, body, request, state) do
    case id do
      0 ->
        Kernel.send(Kernel.self(), {"users_locations", %{"body" => %{"errors" => "Invalid User"}}})
        {:ok, request, state}
      id ->
        users_locations_post_2(id, body, request, state)
    end
  end

  def users_locations_post_2(id, body, request, state) do
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
        Kernel.send(Kernel.self(), {"users_locations", %{"body" => %{"errors" => errors}}})
        {:ok, request, state}
      :ok ->
        users_locations_post_3(id, body, request, state)
    end
  end

  def users_locations_post_3(id, body, request, state) do
    changeset = UserLocation.changeset(
      %UserLocation{}, Map.merge(body, %{"user_id" => id, "point" => Utilities.get_point(body["point"])})
    )
    case changeset.valid? do
      false ->
        Kernel.spawn(
          fn() ->
            Utilities.log(
              "users_locations_post_2()",
              %{"changeset" => %{"params" => changeset.errors, "errors" => changeset.errors}}
            )
          end
        )
        Kernel.send(Kernel.self(), {"users_locations", %{"body" => %{"errors" => changeset.errors}}})
        {:ok, request, state}
      _ ->
        users_locations_post_4(changeset, request, state)
    end
  end

  def users_locations_post_4(changeset, request, state) do
    case Repo.insert(changeset) do
      {:ok, user_location} ->
        {:ok, connection} = Connection.open(Application.get_env(:websockets, :broker))
        {:ok, channel} = Channel.open(connection)
        Basic.publish(
          channel,
          WebSockets.get_exchange(),
          WebSockets.get_routing_key(),
          "{\"subject\":\"users_locations\",\"body\":\"#{user_location.id}\"}"
        )
        {:ok, request, state}
      {:error, changeset} ->
        Kernel.spawn(
          fn() ->
            Utilities.log(
              "users_locations_post_3()",
              %{"changeset" => %{"params" => changeset.errors, "errors" => changeset.errors}}
            )
          end
        )
        Kernel.send(Kernel.self(), {"users_locations", %{"body" => %{"errors" => "Invalid Body"}}})
        {:ok, request, state}
    end
  end
end
