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

  def get_direction(direction) do
    :io_lib.format("~-3s", [direction])
  end

  def get_id(id) do
    :io_lib.format("~9B", [id])
  end

  def get_module(module) do
    :io_lib.format("~-8s", [module])
  end
end
