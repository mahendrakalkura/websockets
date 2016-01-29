defmodule WebSockets do
  @moduledoc ""

  def start(_type, _arguments) do
    WebSockets.Supervisor.start_link()
  end
end
