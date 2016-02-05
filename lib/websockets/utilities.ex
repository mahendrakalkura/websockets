defmodule WebSockets.Utilities do
  @moduledoc false

  alias Geo.WKT, as: WKT
  alias GeoPotion.Distance, as: Distance
  alias GeoPotion.Vector, as: Vector
  alias WebSockets.Clients, as: Clients

  require ExSentry
  require GeoPotion.Distance
  require GeoPotion.Vector
  require Kernel
  require Logger

  def log(module, direction, pid, subject) do
    Logger.info("[#{get_module(module)}] [#{get_direction(direction)}] [#{get_id(get_id(pid))}] #{subject}")
  end

  def log(module, direction, subject) do
    Logger.info("[#{get_module(module)}] [#{get_direction(direction)}] #{subject}")
  end

  def log(message, extra) do
    ExSentry.capture_message(message, extra: extra)
  end

  def get_direction(string) do
    :io_lib.format("~-3s", [string])
  end

  def get_distance({a, b}, {c, d}) do
    Distance.to_ft(Vector.calculate(%{longitude: a, latitude: b}, %{longitude: c, latitude: d}).distance).value
  end

  def get_id(integer) when Kernel.is_integer(integer) do
     :io_lib.format("~9B", [integer])
  end

  def get_id(pid) when Kernel.is_pid(pid) do
    Clients.select_one(pid)
  end

  def get_module(string) do
    :io_lib.format("~-8s", [string])
  end

  def get_point(%{"longitude" => longitude, "latitude" => latitude}) do
    WKT.decode("SRID=4326;POINT(#{longitude} #{latitude})")
  end

  def get_point(_) do
    nil
  end
end
