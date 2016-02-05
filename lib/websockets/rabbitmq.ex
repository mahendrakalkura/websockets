defmodule WebSockets.RabbitMQ do
  @moduledoc false

  alias AMQP.Basic, as: Basic
  alias AMQP.Channel, as: Channel
  alias AMQP.Connection, as: Connection
  alias AMQP.Exchange, as: Exchange
  alias AMQP.Queue, as: Queue
  alias Ecto.Query, as: Query
  alias WebSockets.Clients, as: Clients
  alias WebSockets.Repo, as: Repo
  alias WebSockets.Repo.Block, as: Block
  alias WebSockets.Repo.Message, as: Message
  alias WebSockets.Repo.Notification, as: Notification
  alias WebSockets.Repo.Tellcard, as: Tellcard
  alias WebSockets.Repo.UserLocation, as: UserLocation
  alias WebSockets.Utilities, as: Utilities

  require Application
  require Ecto.Query
  require JSX
  require Kernel
  require List
  require WebSockets

  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init([]) do
    {:ok, connection} = Connection.open(Application.get_env(:websockets, :broker))
    {:ok, channel} = Channel.open(connection)
    Basic.qos(channel, prefetch_count: 1)
    Exchange.direct(channel, WebSockets.get_exchange(), durable: true)
    Queue.declare(channel, WebSockets.get_queue(), durable: true)
    Queue.bind(channel, WebSockets.get_queue(), WebSockets.get_exchange())
    {:ok, _} = Basic.consume(channel, WebSockets.get_queue())
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
        Kernel.spawn(fn() -> handle_info(contents) end)
      {:error, reason} ->
        Kernel.spawn(fn() -> Utilities.log("handle_info()", %{"contents" => contents, "reason" => reason}) end)
    end
    Kernel.spawn(fn() -> Basic.ack(channel, delivery_tag) end)
    {:noreply, channel}
  end

  def handle_info(%{"args" => args}) do
    Kernel.spawn(fn() -> handle_info(List.first(args)) end)
  end

  def handle_info(%{"subject" => subject, "body" => body, "action" => action, "users" => users}) do
    Kernel.spawn(fn() -> info(subject, body, action, users) end)
  end

  def handle_info(%{"subject" => subject, "body" => body, "user_ids" => user_ids}) do
    Kernel.spawn(fn() -> info(subject, body, user_ids) end)
  end

  def handle_info(%{"subject" => subject, "body" => body}) do
    Kernel.spawn(fn() -> info(subject, body) end)
  end

  def handle_info(contents) do
    Kernel.spawn(fn() -> Utilities.log("handle_info()", %{"contents" => contents}) end)
  end

  def info("messages", body, action, users) do
    Kernel.spawn(fn() -> Utilities.log("RabbitMQ", "In", "messages") end)
    Kernel.spawn(fn() -> messages_1(body, action, users) end)
  end

  def info(subject, body, action, users) do
    Kernel.spawn(
      fn() ->
        Utilities.log("info()", %{"subject" => subject, "body" => body, "action" => action, "users" => users})
      end
    )
  end

  def info("master_tells", body, user_ids) do
    Kernel.spawn(fn() -> Utilities.log("RabbitMQ", "In", "master_tells") end)
    Kernel.spawn(fn() -> master_tells_1(body, user_ids) end)
  end

  def info("posts", body, user_ids) do
    Kernel.spawn(fn() -> Utilities.log("RabbitMQ", "In", "posts") end)
    Kernel.spawn(fn() -> posts_1(body, user_ids) end)
  end

  def info(subject, body, user_ids) do
    Kernel.spawn(fn() -> Utilities.log("info()", %{"subject" => subject, "body" => body, "user_ids" => user_ids}) end)
  end

  def info("blocks", body) do
    Kernel.spawn(fn() -> Utilities.log("RabbitMQ", "In", "blocks") end)
    Kernel.spawn(fn() -> blocks_1(body) end)
  end

  def info("messages", body) do
    Kernel.spawn(fn() -> Utilities.log("RabbitMQ", "In", "master_tells") end)
    Kernel.spawn(fn() -> messages_1(body) end)
  end

  def info("notifications", body) do
    Kernel.spawn(fn() -> Utilities.log("RabbitMQ", "In", "notifications") end)
    Kernel.spawn(fn() -> notifications_1(body) end)
  end

  def info("profile", body) do
    Kernel.spawn(fn() -> Utilities.log("RabbitMQ", "In", "profile") end)
    Kernel.spawn(fn() -> profile_1(body) end)
  end

  def info("users_locations", body) do
    Kernel.spawn(fn() -> Utilities.log("RabbitMQ", "In", "users_locations") end)
    Kernel.spawn(fn() -> users_locations_1(body) end)
  end

  def info(subject, body) do
    Kernel.spawn(fn() -> Utilities.log("info()", %{"subject" => subject, "body" => body}) end)
  end

  def messages_1(body, action, users) do
    Enum.each(users, fn(user) -> Kernel.spawn(fn() -> messages_2(body, action, user) end) end)
  end

  def messages_1(id) do
    Kernel.spawn(
      fn() ->
        Message
        |> Query.from()
        |> Query.where(id: ^id)
        |> Query.preload([
          :master_tell,
          :post,
          :attachments,
          user_source: :settings,
          user_destination: :settings,
          user_status: :attachments
        ])
        |> Repo.one()
        |> messages_2()
      end
    )
  end

  def messages_2(body, action, user) do
    Enum.each(
      Clients.select_any(user), fn(pid) -> Kernel.spawn(fn() -> Kernel.send(pid, {"messages", body, action}) end) end
    )
  end

  def messages_2(message) do
    Kernel.spawn(
      Enum.each(
        Clients.select_any(message.user_source_id),
        fn(pid) -> Kernel.spawn(fn() -> Kernel.send(pid, {"messages", Repo.get_message(message)}) end) end
      )
    )
    Kernel.spawn(
      Enum.each(
        Clients.select_any(message.user_destination_id),
        fn(pid) -> Kernel.spawn(fn() -> Kernel.send(pid, {"messages", Repo.get_message(message)}) end) end
      )
    )
  end

  def master_tells_1(body, user_ids) do
    Enum.each(user_ids, fn(user_id) -> Kernel.spawn(fn() -> master_tells_2(body, user_id) end) end)
  end

  def master_tells_2(body, user_id) do
    Enum.each(
      Clients.select_any(user_id), fn(pid) -> Kernel.spawn(fn() -> Kernel.send(pid, {"master_tells", body}) end) end
    )
  end

  def posts_1(body, user_ids) do
    Enum.each(user_ids, fn(user_id) -> Kernel.spawn(fn() -> posts_2(body, user_id) end) end)
  end

  def posts_2(body, user_id) do
    Enum.each(Clients.select_any(user_id), fn(pid) -> Kernel.spawn(fn() -> Kernel.send(pid, {"posts", body}) end) end)
  end

  def blocks_1(id) do
    Kernel.spawn(fn() -> blocks_2(Repo.get!(Block, id)) end)
  end

  def blocks_2(block) do
    Kernel.send(Clients.select_any(block.user_destination_id), {"blocks", block.user_source_id})
  end

  def notifications_1(id) do
    Kernel.spawn(fn() -> notifications_2(Repo.get!(Notification, id)) end)
  end

  def notifications_2(notification) do
    Kernel.send(Clients.select_any(notification.user_id), {"blocks", Repo.get_notification(notification)})
  end

  def profile_1(user_destination_id) do
    Enum.each(
      Repo.all(Tellcard, user_destination_id: user_destination_id),
      fn(tellcard) -> Kernel.spawn(fn() -> profile_2(tellcard) end) end
    )
  end

  def profile_2(tellcard) do
    Enum.each(
      Clients.select_any(tellcard.user_source_id),
      fn(pid) -> Kernel.spawn(fn() -> Kernel.send(pid, {"profile", tellcard.user_destination_id}) end) end
    )
  end

  def users_locations_1(id) do
    Kernel.spawn(fn() -> users_locations_2(Repo.get!(UserLocation, id)) end)
  end

  def users_locations_2(user_location) do
    Kernel.spawn(
      fn() ->
        users_locations = UserLocation
        |> Query.from()
        |> Query.where(user_id: ^user_location.user_id)
        |> Query.order_by(desc: :id)
        |> Query.limit(2)
        |> Repo.all()
        users_locations_3(users_locations)
        users_locations_4(users_locations)
        users_locations_5(users_locations)
      end
    )
  end

  def users_locations_3(_users_locations) do
    # TODO
  end

  def users_locations_4(_users_locations) do
    # TODO
  end

  def users_locations_5(users_locations) when Kernel.length(users_locations) === 1 do
    Kernel.spawn(fn() -> users_locations_6(Enum.at(users_locations, 0)) end)
  end

  def users_locations_5(users_locations) when Kernel.length(users_locations) === 2 do
    Kernel.spawn(fn() -> users_locations_6(Enum.at(users_locations, 0)) end)
    {a, b} = Enum.at(users_locations, 0).point.coordinates
    {c, d} = Enum.at(users_locations, 1).point.coordinates
    if Utilities.get_distance({a, b}, {c, d}) > 300.00 do
      Kernel.spawn(fn() -> users_locations_6(Enum.at(users_locations, 1)) end)
    end
  end

  def users_locations_6(_user_location) do
    # TODO
  end
end
