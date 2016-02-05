defmodule WebSockets.RabbitMQ do
  @moduledoc false

  @exchange "api.management.commands.websockets"
  @queue "api.management.commands.websockets"

  alias AMQP.Basic, as: Basic
  alias AMQP.Channel, as: Channel
  alias AMQP.Connection, as: Connection
  alias AMQP.Exchange, as: Exchange
  alias AMQP.Queue, as: Queue
  alias Ecto.Adapters.SQL, as: SQL
  alias WebSockets.Clients, as: Clients
  alias WebSockets.Repo, as: Repo
  alias WebSockets.Utilities, as: Utilities

  require Application
  require JSX
  require Kernel

  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init([]) do
    {:ok, connection} = Connection.open(Application.get_env(:websockets, :broker))
    {:ok, channel} = Channel.open(connection)
    Basic.qos(channel, prefetch_count: 1)
    Exchange.direct(channel, @exchange, durable: true)
    Queue.declare(channel, @queue, durable: true)
    Queue.bind(channel, @queue, @exchange)
    {:ok, _} = Basic.consume(channel, @queue)
    {:ok, channel}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, channel) do
    {:noreply, channel}
  end

  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, channel) do
    {:stop, :normal, channel}
  end

  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, channel) do
    {:noreply, channel}
  end

  def handle_info({:basic_deliver, contents, %{delivery_tag: delivery_tag, redelivered: redelivered}}, channel) do
    case JSX.decode(contents) do
      {:ok, %{"subject" => subject, "body" => body, "action" => action, "users" => users}} ->
        Kernel.spawn(fn() -> info(subject, body, action, users) end)
        Kernel.spawn(fn() -> Basic.ack(channel, delivery_tag) end)
      {:ok, %{"subject" => subject, "body" => body, "user_ids" => user_ids}} ->
        Kernel.spawn(fn() -> info(subject, body, user_ids) end)
        Kernel.spawn(fn() -> Basic.ack(channel, delivery_tag) end)
      {:ok, %{"subject" => subject, "body" => body}} ->
        Kernel.spawn(fn() -> info(subject, body) end)
        Kernel.spawn(fn() -> Basic.ack(channel, delivery_tag) end)
      {:ok, _} ->
        Kernel.spawn(fn() -> Utilities.log("info()", %{"contents" => contents}) end)
        Kernel.spawn(fn() -> Basic.reject(channel, delivery_tag, requeue: not redelivered) end)
      {:error, reason} ->
        Kernel.spawn(fn() -> Utilities.log("info()", %{"contents" => contents, "reason" => reason}) end)
        Kernel.spawn(fn() -> Basic.reject(channel, delivery_tag, requeue: not redelivered) end)
    end
    {:noreply, channel}
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

  def info("messages", _body) do
    Kernel.spawn(fn() -> Utilities.log("RabbitMQ", "In", "master_tells") end)
    # TODO
  end

  def info("notifications", body) do
    Kernel.spawn(fn() -> Utilities.log("RabbitMQ", "In", "notifications") end)
    Kernel.spawn(fn() -> notifications_1(body) end)
  end

  def info("profile", body) do
    Kernel.spawn(fn() -> Utilities.log("RabbitMQ", "In", "profile") end)
    Kernel.spawn(fn() -> profile_1(body) end)
  end

  def info("users_locations", _body) do
    Kernel.spawn(fn() -> Utilities.log("RabbitMQ", "In", "users_locations") end)
    # TODO
  end

  def info(subject, body) do
    Kernel.spawn(fn() -> Utilities.log("info()", %{"subject" => subject, "body" => body}) end)
  end

  def messages_1(body, action, users) do
    Enum.each(users, fn(user) -> Kernel.spawn(fn() -> messages_2(body, action, user) end) end)
  end

  def messages_2(body, action, user) do
    Enum.each(
      Clients.select_any(user), fn(pid) -> Kernel.spawn(fn() -> Kernel.send(pid, {"messages", body, action}) end) end
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
    case SQL.query(Repo, "SELECT user_source_id, user_destination_id FROM api_blocks WHERE id = $1", [id], []) do
      {:ok, %{rows: rows, num_rows: 1}} -> Kernel.spawn(fn() -> blocks_2(rows) end)
    end
  end

  def blocks_2(rows) do
    Enum.each(rows, fn(row) -> Kernel.spawn(fn() -> blocks_3(Enum.at(row, 0), Enum.at(row, 1)) end) end)
  end

  def blocks_3(user_source_id, user_destination_id) do
    Enum.each(
      Clients.select_any(user_destination_id),
      fn(pid) -> Kernel.spawn(fn() -> Kernel.send(pid, {"blocks", user_source_id}) end) end
    )
  end

  def notifications_1(id) do
    case SQL.query(
      Repo, "SELECT id, user_id, type, contents, status, timestamp FROM api_notifications WHERE id = $1", [id], []
    ) do
      {:ok, %{rows: rows, num_rows: 1}} -> Kernel.spawn(fn() -> notifications_2(rows) end)
    end
  end

  def notifications_2(rows) do
    Enum.each(
      rows,
      fn(row) ->
        Kernel.spawn(
          fn() ->
            notifications_3(
              %{
                "id" => Enum.at(row, 0),
                "user_id" => Enum.at(row, 1),
                "type" => Enum.at(row, 2),
                "contents" => Enum.at(row, 3),
                "status" => Enum.at(row, 4),
                "timestamp" => Enum.at(row, 5)
              }
            )
          end
        )
      end
    )
  end

  def notifications_3(notification) do
    Enum.each(
      Clients.select_any(notification.user_id),
      fn(pid) ->
        Kernel.spawn(
          fn() ->
            Kernel.send(
              pid,
              {
                "blocks",
                %{
                  "id" => notification.id,
                  "user_id" => notification.user_id,
                  "type" => notification.type,
                  "contents" => notification.contents,
                  "status" => notification.status,
                  "timestamp" => notification.timestamp
                }
              }
            )
          end
        )
      end
    )
  end

  def profile_1(user_destination_id) do
    case SQL.query(
      Repo, "SELECT user_source_id FROM api_tellcards WHERE user_destination_id = $1", [user_destination_id], []
    ) do
      {:ok, %{rows: rows, num_rows: _}} -> Kernel.spawn(fn() -> profile_2(rows, user_destination_id) end)
    end
  end

  def profile_2(rows, user_destination_id) do
    Enum.each(rows, fn(row) -> Kernel.spawn(fn() -> profile_3(Enum.at(row, 0), user_destination_id) end) end)
  end

  def profile_3(user_source_id, user_destination_id) do
    Enum.each(
      Clients.select_any(user_source_id),
      fn(pid) -> Kernel.spawn(fn() -> Kernel.send(pid, {"profile", user_destination_id}) end) end
    )
  end
end
