defmodule WebSockets.RabbitMQ do
  @moduledoc false

  use GenServer

  alias AMQP.Basic, as: Basic
  alias AMQP.Channel, as: Channel
  alias AMQP.Connection, as: Connection
  alias AMQP.Exchange, as: Exchange
  alias AMQP.Queue, as: Queue
  alias Ecto.Adapters.SQL, as: SQL
  alias Ecto.Query, as: Query
  alias WebSockets.Clients, as: Clients
  alias WebSockets.Repo, as: Repo
  alias WebSockets.Repo.Block, as: Block
  alias WebSockets.Repo.Message, as: Message
  alias WebSockets.Repo.Notification, as: Notification
  alias WebSockets.Repo.Tellcard, as: Tellcard
  alias WebSockets.Repo.UserLocation, as: UserLocation
  alias WebSockets.Utilities, as: Utilities

  require Ecto.Query
  require JSX
  require WebSockets

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init([]) do
    {:ok, connection} = Connection.open(Application.get_env(:websockets, :broker))
    {:ok, channel} = Channel.open(connection)
    Basic.qos(channel, prefetch_count: 1)
    Exchange.direct(channel, WebSockets.get_exchange(:websockets), durable: true)
    Queue.declare(channel, WebSockets.get_queue(:websockets), durable: true)
    Queue.bind(channel, WebSockets.get_queue(:websockets), WebSockets.get_exchange(:websockets))
    {:ok, _} = Basic.consume(channel, WebSockets.get_queue(:websockets))
    {:ok, channel}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _}}, channel) do
    {:noreply, channel}
  end

  def handle_info({:basic_cancel, %{consumer_tag: _}}, channel) do
    {:stop, :normal, channel}
  end

  def handle_info({:basic_cancel_ok, %{consumer_tag: _}}, channel) do
    {:noreply, channel}
  end

  def handle_info({:basic_deliver, contents, %{delivery_tag: delivery_tag, redelivered: _}}, channel) do
    case JSX.decode(contents) do
      {:ok, contents} ->
        spawn(fn() -> handle_info(contents) end)
      {:error, reason} ->
        spawn(fn() -> Utilities.log("handle_info()", %{"contents" => contents, "reason" => reason}) end)
    end
    spawn(fn() -> Basic.ack(channel, delivery_tag) end)
    {:noreply, channel}
  end

  def handle_info(%{"args" => args}) do
    spawn(fn() -> handle_info(List.first(args)) end)
  end

  def handle_info(%{"subject" => subject, "body" => body, "action" => action, "users" => users}) do
    spawn(fn() -> info(subject, body, action, users) end)
  end

  def handle_info(%{"subject" => subject, "body" => body, "user_ids" => user_ids}) do
    spawn(fn() -> info(subject, body, user_ids) end)
  end

  def handle_info(%{"subject" => subject, "body" => body}) do
    spawn(fn() -> info(subject, body) end)
  end

  def handle_info(contents) do
    spawn(fn() -> Utilities.log("handle_info()", %{"contents" => contents}) end)
  end

  def info("messages", body, action, users) do
    spawn(fn() -> Utilities.log("RabbitMQ", "In", "messages") end)
    spawn(fn() -> messages_1(body, action, users) end)
  end

  def info(subject, body, action, users) do
    spawn(
      fn() ->
        Utilities.log("info()", %{"subject" => subject, "body" => body, "action" => action, "users" => users})
      end
    )
  end

  def info("master_tells", body, user_ids) do
    spawn(fn() -> Utilities.log("RabbitMQ", "In", "master_tells") end)
    spawn(fn() -> master_tells_1(body, user_ids) end)
  end

  def info("posts", body, user_ids) do
    spawn(fn() -> Utilities.log("RabbitMQ", "In", "posts") end)
    spawn(fn() -> posts_1(body, user_ids) end)
  end

  def info(subject, body, user_ids) do
    spawn(fn() -> Utilities.log("info()", %{"subject" => subject, "body" => body, "user_ids" => user_ids}) end)
  end

  def info("blocks", body) do
    spawn(fn() -> Utilities.log("RabbitMQ", "In", "blocks") end)
    spawn(fn() -> blocks_1(body) end)
  end

  def info("messages", body) do
    spawn(fn() -> Utilities.log("RabbitMQ", "In", "master_tells") end)
    spawn(fn() -> messages_1(body) end)
  end

  def info("notifications", body) do
    spawn(fn() -> Utilities.log("RabbitMQ", "In", "notifications") end)
    spawn(fn() -> notifications_1(body) end)
  end

  def info("profile", body) do
    spawn(fn() -> Utilities.log("RabbitMQ", "In", "profile") end)
    spawn(fn() -> profile_1(body) end)
  end

  def info("users_locations", body) do
    spawn(fn() -> Utilities.log("RabbitMQ", "In", "users_locations") end)
    spawn(fn() -> users_locations_1(body) end)
  end

  def info(subject, body) do
    spawn(fn() -> Utilities.log("info()", %{"subject" => subject, "body" => body}) end)
  end

  def messages_1(body, action, users) do
    Enum.each(users, fn(user) -> spawn(fn() -> messages_2(body, action, user) end) end)
  end

  def messages_1(id) do
    spawn(
      fn() ->
        Message
        |> Query.from()
        |> Query.where(id: ^id)
        |> Query.preload([
          :master_tell,
          :attachments,
          user_source: :settings,
          user_destination: :settings,
          user_status: :attachments,
          post: :attachments
        ])
        |> Repo.one()
        |> messages_2()
      end
    )
  end

  def messages_2(body, action, user) do
    Enum.each(
      Clients.select_any(user), fn(pid) -> spawn(fn() -> send(pid, {"messages", body, action}) end) end
    )
  end

  def messages_2(message) do
    spawn(fn() -> messages_3(message, "source", "destination") end)
    spawn(fn() -> messages_3(message, "destination", "source") end)
  end

  def messages_3(message, "source", "destination") do
    Enum.each(Clients.select_any(message.user_destination_id), fn(pid) -> messages_4(message, "user_source", pid) end)
  end

  def messages_3(message, "destination", "source") do
    Enum.each(Clients.select_any(message.user_source_id), fn(pid) -> messages_4(message, "user_destination", pid) end)
  end

  def messages_4(message, key, pid) do
    spawn(
      fn() ->
        message = Repo.get_message(message)
        unless message[key]["settings"]["email"] do
          put_in(message, [key, "email"], nil)
        end
        unless message[key]["settings"]["last_name"] do
          put_in(message, [key, "last_name"], nil)
        end
        unless message[key]["settings"]["phone"] do
          put_in(message, [key, "phone"], nil)
        end
        unless message[key]["settings"]["photo"] do
          put_in(message, [key, "photo_original"], nil)
        end
        unless message[key]["settings"]["photo"] do
          put_in(message, [key, "photo_preview"], nil)
        end
        message = update_in(message["user_source"], &Map.delete(&1, "settings"))
        message = update_in(message["user_destination"], &Map.delete(&1, "settings"))
        send(pid, {"messages", message})
      end
    )
  end

  def master_tells_1(body, user_ids) do
    Enum.each(user_ids, fn(user_id) -> spawn(fn() -> master_tells_2(body, user_id) end) end)
  end

  def master_tells_2(body, user_id) do
    Enum.each(
      Clients.select_any(user_id), fn(pid) -> spawn(fn() -> send(pid, {"master_tells", body}) end) end
    )
  end

  def posts_1(body, user_ids) do
    Enum.each(user_ids, fn(user_id) -> spawn(fn() -> posts_2(body, user_id) end) end)
  end

  def posts_2(body, user_id) do
    Enum.each(Clients.select_any(user_id), fn(pid) -> spawn(fn() -> send(pid, {"posts", body}) end) end)
  end

  def blocks_1(id) do
    spawn(fn() -> blocks_2(Repo.get!(Block, id)) end)
  end

  def blocks_2(block) do
    Enum.each(
      Clients.select_any(block.user_destination_id),
      fn(pid) -> spawn(fn() -> send(pid, {"blocks", block.user_source_id}) end)
      end
    )
  end

  def notifications_1(id) do
    spawn(fn() -> notifications_2(Repo.get!(Notification, id)) end)
  end

  def notifications_2(notification) do
    Enum.each(
      Clients.select_any(notification.user_id),
      fn(pid) -> spawn(fn() -> send(pid, {"notifications", Repo.get_notification(notification)}) end)
      end
    )
  end

  def profile_1(user_destination_id) do
    Enum.each(
      Repo.all(Tellcard, user_destination_id: user_destination_id),
      fn(tellcard) -> spawn(fn() -> profile_2(tellcard) end) end
    )
  end

  def profile_2(tellcard) do
    Enum.each(
      Clients.select_any(tellcard.user_source_id),
      fn(pid) -> spawn(fn() -> send(pid, {"profile", tellcard.user_destination_id}) end) end
    )
  end

  def users_locations_1(id) do
    spawn(fn() -> users_locations_2(Repo.get!(UserLocation, id)) end)
  end

  def users_locations_2(user_location) do
    spawn(
      fn() ->
        users_locations = UserLocation
        |> Query.from()
        |> Query.where(user_id: ^user_location.user_id)
        |> Query.order_by(desc: :id)
        |> Query.limit(2)
        |> Query.offset(0)
        |> Repo.all()
        |> Repo.preload([:tellzone, :network])
        users_locations_3(users_locations)
        users_locations_4(users_locations)
      end
    )
  end

  def users_locations_3(users_locations) do
    user_location = Enum.at(users_locations, 0)
    Enum.each(
      Clients.select_any(user_location.user_id),
      fn(pid) ->
        spawn(fn() -> send(pid, {"messages", Utilities.get_radar_post_1(user_location)}) end)
      end
    )
  end

  def users_locations_4(
    users_locations
  ) when is_list(users_locations) and length(users_locations) === 2 do
    user_location_1 = Enum.at(users_locations, 0)
    user_location_2 = Enum.at(users_locations, 1)

    status = false
    if user_location_1.is_casting and user_location_2.is_casting do
      if (
        Map.has_key?(user_location_1, :tellzone_id)
        and
        !is_nil(user_location_1.tellzone_id)
        and
        (user_location_2.tellzone_id != user_location_1.tellzone_id)
      ) do
        status = true
      end
    end
    if user_location_1.is_casting and not user_location_2.is_casting do
      if user_location_1.tellzone_id do
        status = True
      end
    end
    if status do
      badge = 0
      count = case SQL.query(
        Repo,
        """
        SELECT COUNT(id) FROM api_messages WHERE user_destination_id = $1 AND status = $2
        """,
        [user_location_1.user_id, "Unread"],
        []
      ) do
        {:ok, %{rows: rows}} -> Enum.at(rows, 0)
        _ -> []
      end
      badge = badge + if !Enum.empty?(count), do: badge + Enum.at(count, 0), else: 0
      count = case SQL.query(
        Repo,
        """
        SELECT COUNT(id) FROM api_notifications WHERE user_id = $1 AND status = $2
        """,
        [user_location_1.user_id, "Unread"],
        []
      ) do
        {:ok, %{rows: rows}} -> Enum.at(rows, 0)
        _ -> []
      end
      badge = badge + if !Enum.empty?(count), do: Enum.at(count, 0), else: 0
      Utilities.publish(
        "api.tasks.push_notifications",
        "api.tasks.push_notifications",
        [
          user_location_1.user_id,
          %{
            "aps" => %{
              "alert" => %{
                "title" => "You are now at #{user_location_1.tellzone.name} zone",
              },
              "badge" => badge,
            },
            "tellzone_id" => user_location_1.tellzone_id,
            "type" => "zone_change",
          }
        ],
        [content_type: "application/json"]
      )
    end
    unless (
      user_location_1.network_id === user_location_2.network_id
      and
      user_location_1.tellzone_id === user_location_2.tellzone_id
    ) do
      users_locations_4(user_location_1)
    end
  end

  def users_locations_4(
    users_locations
  ) when is_list(users_locations) and length(users_locations) === 1 do
    users_locations_4(Enum.at(users_locations, 0))
  end

  def users_locations_4(user_location) do
    blocks = Utilities.get_blocks(user_location.user_id)
    {longitude, latitude} = user_location.point.coordinates
    user_ids = case SQL.query(
      Repo,
      """
      SELECT api_users_locations.user_id AS user_id
      FROM api_users_locations
      WHERE
          api_users_locations.user_id != $1
          AND
          (
              api_users_locations.network_id = $2
              OR
              api_users_locations.tellzone_id = $3
              OR
              ST_DWithin(
                ST_Transform(ST_GeomFromText($4, 4326), 2163),
                ST_Transform(api_users_locations.point, 2163),
                $5
              )
          )
          AND
          api_users_locations.is_casting IS TRUE
          AND
          api_users_locations.timestamp > NOW() - INTERVAL '1 minute'
      ORDER BY api_users_locations.user_id ASC
      """,
      [
        user_location.user_id,
        user_location.network_id,
        user_location.tellzone_id,
        "POINT(#{longitude} #{latitude})",
        300.00
      ],
      []
    ) do
      {:ok, %{rows: rows}} -> Enum.uniq(Enum.map(rows, fn([user_id]) -> user_id end))
      _ -> []
    end
    unless Enum.empty?(user_ids) do
      user_ids = Enum.map(
        user_ids,
        fn(user_id) ->
          unless user_id in Map.get(blocks, user_location.user_id, []) do
            user_id
          end
        end
      )
      user_ids = Enum.reject(user_ids, &(is_nil(&1)))
      Utilities.publish(
        WebSockets.get_exchange(:websockets),
        WebSockets.get_routing_key(:websockets),
        %{"user_ids" => user_ids, "subject" => "master_tells", "body" => %{"type" => "home"}}
      )
      Utilities.publish(
        WebSockets.get_exchange(:websockets),
        WebSockets.get_routing_key(:websockets),
        %{
          "user_ids" => user_ids,
          "subject" => "master_tells",
          "body" => %{
            "id" => user_location.network_id,
            "type" => "networks"
          }
        }
      )
      Utilities.publish(
        WebSockets.get_exchange(:websockets),
        WebSockets.get_routing_key(:websockets),
        %{
          "user_ids" => user_ids,
          "subject" => "master_tells",
          "body" => %{
            "id" => user_location.tellzone_id,
            "type" => "tellzones"
          }
        }
      )
    end
  end
end
