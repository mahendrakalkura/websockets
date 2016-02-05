defmodule WebSockets do
  @moduledoc false

  def start(_type, _arguments) do
    WebSockets.Supervisor.start_link()
  end

  def get_exchange() do
    "api.management.commands.websockets"
  end

  def get_queue() do
    "api.management.commands.websockets"
  end

  def get_routing_key() do
    "api.management.commands.websockets"
  end
end
