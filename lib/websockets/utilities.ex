defmodule WebSockets.Utilities do
  @moduledoc ""

  require Kernel
  require Logger

  def log(module, direction, id, subject) do
    Kernel.spawn(
      fn -> Logger.info("[#{get_module(module)}] [#{get_direction(direction)}] [#{get_id(id)}] #{subject}") end
    )
  end

  def log(module, direction, subject) do
    Kernel.spawn(fn -> Logger.info("[#{get_module(module)}] [#{get_direction(direction)}] #{subject}") end)
  end

  def get_direction(string) do
    :io_lib.format("~-3s", [string])
  end

  def get_id(integer) when is_integer(integer) do
    :io_lib.format("~9B", [integer])
  end

  def get_id(pid) when is_pid(pid) do
    case Clients.select_one(pid) do
      {:ok, id} -> id
      _ -> 0
    end
  end

  def get_module(string) do
    :io_lib.format("~-8s", [string])
  end
end
