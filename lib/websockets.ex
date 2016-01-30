defmodule WebSockets do
  @moduledoc false

  def start(_type, _arguments) do
    WebSockets.Supervisor.start_link()
  end
end
