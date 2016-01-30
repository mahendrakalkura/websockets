defmodule WebSockets.RabbitMQ do
  @moduledoc ""

  @exchange "api.management.commands.websockets"
  @queue "api.management.commands.websockets"

  alias AMQP.Basic, as: Basic
  alias AMQP.Channel, as: Channel
  alias AMQP.Connection, as: Connection
  alias AMQP.Exchange, as: Exchange
  alias AMQP.Queue, as: Queue

  require Application
  require ExSentry
  require JSX
  require Kernel
  require Logger

  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init(_options) do
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

  def handle_info({:basic_deliver, contents, %{delivery_tag: tag, redelivered: redelivered}}, channel) do
    Kernel.spawn(fn -> consume(contents, channel, tag, redelivered) end)
    {:noreply, channel}
  end

  def consume(contents, channel, tag, redelivered) do
    Kernel.spawn(fn -> consume(contents, JSX.decode(contents), channel, tag, redelivered) end)
  end

  def consume(_contents, {:ok, %{"subject" => subject, "body" => body}}, channel, tag, _redelivered) do
    Kernel.spawn(fn -> process(subject, body) end)
    Kernel.spawn(fn -> Basic.ack(channel, tag) end)
  end

  def consume(contents, {:ok, _}, channel, tag, redelivered) do
    Kernel.spawn(fn -> ExSentry.capture_message("Invalid Contents (#1)", extra: %{"contents" => contents}) end)
    Kernel.spawn(fn -> Basic.reject(channel, tag, requeue: not redelivered) end)
  end

  def consume(contents, {:error, reason}, channel, tag, redelivered) do
    Kernel.spawn(
      fn -> ExSentry.capture_message("Invalid Contents (#2)", extra: %{"contents" => contents, "reason" => reason}) end
    )
    Kernel.spawn(fn -> Basic.reject(channel, tag, requeue: not redelivered) end)
  end

  def process("blocks", _body) do
    Kernel.spawn(fn -> log("In", "blocks") end)
  end

  def process("master_tells", _body) do
    Kernel.spawn(fn -> log("In", "master_tells") end)
  end

  def process("messages", _body) do
    Kernel.spawn(fn -> log("In", "messages") end)
  end

  def process("notifications", _body) do
    Kernel.spawn(fn -> log("In", "notifications") end)
  end

  def process("posts", _body) do
    Kernel.spawn(fn -> log("In", "posts") end)
  end

  def process("users", _body) do
    Kernel.spawn(fn -> log("In", "users") end)
  end

  def process("users_locations", _body) do
    Kernel.spawn(fn -> log("In", "users_locations") end)
  end

  def process(subject, body) do
    Kernel.spawn(
      fn -> ExSentry.capture_message("Invalid Contents (#3)", extra: %{"subject" => subject, "body" => body}) end
    )
  end

  def log(direction, subject) do
    direction = :io_lib.format("~-3s", [direction])
    Kernel.spawn(fn -> Logger.info("[RabbitMQ] [#{direction}] #{subject}") end)
  end
end
