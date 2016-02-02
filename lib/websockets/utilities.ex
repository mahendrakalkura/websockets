defmodule WebSockets.Utilities do
  @moduledoc false

  alias WebSockets.Clients, as: Clients

  require ExSentry
  require Kernel
  require Logger

  def log(message, extra) do
    ExSentry.capture_message(message, extra: extra)
  end

  def log(module, direction, id, subject) do
    Logger.info("[#{get_module(module)}] [#{get_direction(direction)}] [#{get_id(id)}] #{subject}")
  end

  def log(module, direction, subject) do
    Logger.info("[#{get_module(module)}] [#{get_direction(direction)}] #{subject}")
  end

  def get_direction(string) do
    :io_lib.format("~-3s", [string])
  end

  def get_id(integer) when Kernel.is_integer(integer) do
    :io_lib.format("~9B", [integer])
  end

  def get_id(pid) when Kernel.is_pid(pid) do
    case Clients.select_one(pid) do
      {:ok, id} -> id
      _ -> 0
    end
  end

  def get_module(string) do
    :io_lib.format("~-8s", [string])
  end
end
