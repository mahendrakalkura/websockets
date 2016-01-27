defmodule WebSockets do
  @moduledoc ""

  def start(_type, _args) do
    WebSockets.Supervisor.start_link()
  end
end
