defmodule WebSockets do
  @moduledoc false

  def start(_type, _arguments), do: WebSockets.Supervisor.start_link

  def get_exchange(:push_notifications), do: "api.tasks.push_notifications"
  def get_exchange(:websockets), do: "api.management.commands.websockets"

  def get_queue(:push_notifications), do: "api.tasks.push_notifications"
  def get_queue(:websockets), do: "api.management.commands.websockets"

  def get_routing_key(:push_notifications), do: "api.tasks.push_notifications"
  def get_routing_key(:websockets), do: "api.management.commands.websockets"
end
