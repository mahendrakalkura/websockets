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

  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, channel) do
    {:stop, :normal, channel}
  end

  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, channel) do
    {:noreply, channel}
  end

  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, channel) do
    {:noreply, channel}
  end

  def handle_info({:basic_deliver, contents, %{delivery_tag: tag, redelivered: redelivered}}, channel) do
    Kernel.spawn(fn -> consume(channel, tag, redelivered, contents) end)
    {:noreply, channel}
  end

  def consume(channel, tag, redelivered, contents) do
    Kernel.spawn(fn -> consume(channel, tag, redelivered, contents, JSX.decode(contents)) end)
  end

  def consume(channel, tag, _redelivered, _contents, {:ok, %{"subject" => subject, "body" => body}}) do
    Kernel.spawn(
      fn ->
        try do
          process(subject, body)
        rescue
          exception ->
            Kernel.spawn(
              fn -> ExSentry.capture_exception(exception, extra: %{"subject" => subject, "body" => body}) end
            )
        end
      end
    )
    Basic.ack(channel, tag)
  end

  def consume(channel, tag, redelivered, contents, {:ok, _}) do
    Kernel.spawn(fn -> ExSentry.capture_message("Invalid Contents (#1)", extra: %{"contents" => contents}) end)
    Kernel.spawn(fn -> Basic.reject(channel, tag, requeue: not redelivered) end)
  end

  def consume(channel, tag, redelivered, contents, {:error, reason}) do
    Kernel.spawn(
      fn -> ExSentry.capture_message("Invalid Contents (#2)", extra: %{"contents" => contents, "reason" => reason}) end
    )
    Kernel.spawn(fn -> Basic.reject(channel, tag, requeue: not redelivered) end)
  end

  def process("blocks", _body) do
  end

  def process("master_tells", _body) do
  end

  def process("messages", _body) do
  end

  def process("notifications", _body) do
  end

  def process("posts", _body) do
  end

  def process("users", _body) do
  end

  def process("users_locations", _body) do
  end

  def process(subject, body) do
    Kernel.spawn(
      fn -> ExSentry.capture_message("Invalid Contents (#3)", extra: %{"subject" => subject, "body" => body}) end
    )
  end
end
