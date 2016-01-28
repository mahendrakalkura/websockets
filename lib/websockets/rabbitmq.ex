defmodule WebSockets.RabbitMQ do
  @moduledoc ""

  @exchange "api.management.commands.websockets"
  @queue "api.management.commands.websockets"

  use AMQP
  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init(_opts) do
    try do
      {:ok, connection} = Connection.open(
        Application.get_env(:websockets, :broker)
      )
      {:ok, channel} = Channel.open(connection)
      Basic.qos(channel, prefetch_count: 1)
      Exchange.direct(channel, @exchange, durable: true)
      Queue.declare(channel, @queue, durable: true)
      Queue.bind(channel, @queue, @exchange)
      {:ok, _consumer_tag} = Basic.consume(channel, @queue)
      {:ok, channel}
    rescue
      exception ->
        ExSentry.capture_exception(exception)
    end
  end

  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, channel) do
    {:stop, :normal, channel}
  end

  def handle_info(
    {:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, channel
  ) do
    {:noreply, channel}
  end

  def handle_info(
    {:basic_consume_ok, %{consumer_tag: _consumer_tag}}, channel
  ) do
    {:noreply, channel}
  end

  def handle_info(
    {:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}},
    channel
  ) do
    spawn fn ->
      consume(channel, tag, redelivered, payload)
    end
    {:noreply, channel}
  end

  def consume(channel, tag, redelivered, contents) do
    try do
      case JSX.decode(contents) do
        {:ok, %{"subject" => subject, "body" => body}} ->
          process(subject, body)
          Basic.ack channel, tag
        _ ->
          ExSentry.capture_message(
            "Invalid Contents", extra: %{"contents": contents}
          )
          Basic.reject channel, tag, requeue: not redelivered
      end
    rescue
      exception ->
        ExSentry.capture_exception(exception)
        Basic.reject channel, tag, requeue: not redelivered
    end
  end

  def process("blocks", body) do
    # IO.inspect(body)
  end

  def process("master_tells", body) do
    # IO.inspect(body)
  end

  def process("messages", body) do
    # IO.inspect(body)
  end

  def process("notifications", body) do
    # IO.inspect(body)
  end

  def process("posts", body) do
    # IO.inspect(body)
  end

  def process("users", body) do
    # IO.inspect(body)
  end

  def process("users_locations", body) do
    # IO.inspect(body)
  end
end
