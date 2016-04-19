defmodule WebSockets.Utilities do
  @moduledoc false

  alias AMQP.Basic, as: Basic
  alias AMQP.Channel, as: Channel
  alias AMQP.Connection, as: Connection
  alias Ecto.Adapters.SQL, as: SQL
  alias Ecto.DateTime, as: DateTime
  alias Geo.WKT, as: WKT
  alias GeoPotion.Distance, as: Distance
  alias GeoPotion.Vector, as: Vector
  alias Timex.Date, as: Date
  alias Timex.DateFormat, as: DateFormat
  alias WebSockets.Clients, as: Clients
  alias WebSockets.Repo, as: Repo

  require ExSentry
  require GeoPotion.Distance
  require GeoPotion.Vector
  require JSX
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

  def publish(exchange, routing_key, contents, options \\ []) do
    {:ok, connection} = Connection.open(Application.get_env(:websockets, :broker))
    {:ok, channel} = Channel.open(connection)
    if exchange == "api.tasks.push_notifications" and routing_key == "api.tasks.push_notifications" do
      contents = %{
        "args" => contents,
        "callbacks" => nil,
        "chord" => nil,
        "errbacks" => nil,
        "eta" => nil,
        "expires" => nil,
        "id" => nil,
        "kwargs" => %{},
        "retries" => 0,
        "task" => "api.tasks.push_notifications",
        "taskset" => nil,
        "timelimit" => [nil, nil],
        "utc" => true,
      }
    end
    {:ok, contents} = JSX.encode(contents)
    Basic.publish(channel, exchange, routing_key, contents, options)
  end

  def get_blocks(user_id) do
    {:ok, %{rows: rows}} = SQL.query(
      Repo,
      """
      SELECT user_source_id, user_destination_id
      FROM api_blocks
      WHERE user_source_id = $1 OR user_destination_id = $1
      """,
      [user_id],
      []
    )
    map = rows
    |> List.flatten
    |> Enum.uniq
    |> Enum.map(fn(key) -> {key, []} end)
    |> Enum.into(%{})
    Enum.reduce(
      rows,
      map,
      fn(row, blocks) ->
        row_0 = Enum.at(row, 0)
        row_1 = Enum.at(row, 1)
        unless row_1 in blocks[row_0] do
          blocks = Map.put(blocks, row_0, Map.get(blocks, row_0) ++ [row_1])
        end
        unless row_0 in blocks[row_1] do
          blocks = Map.put(blocks, row_1, Map.get(blocks, row_1) ++ [row_0])
        end
        blocks
      end
    )
  end

  def get_direction(string) do
    :io_lib.format("~-3s", [string])
  end

  def get_distance({a, b}, {c, d}) do
    Float.ceil(
      Distance.to_ft(Vector.calculate(%{latitude: a, longitude: b}, %{latitude: c, longitude: d}).distance).value,
      10
    )
  end

  def get_formatted_datetime(nil), do: nil
  def get_formatted_datetime(datetime) do
    {:ok, datetime} = DateTime.dump(datetime)
    datetime
    |> Date.from
    |> DateFormat.format!("%Y-%m-%dT%H:%M:%S.%f", :strftime)
  end

  def get_id(integer) when is_integer(integer) do
     :io_lib.format("~9B", [integer])
  end

  def get_id(pid) when is_pid(pid) do
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

  def get_radar_post_1(user_location) do
    {longitude, latitude} = user_location.point.coordinates
    case SQL.query(
      Repo,
      """
      SELECT
          api_tellzones.id AS api_tellzones_id,
          api_tellzones.name AS api_tellzones_name,
          ST_Distance(
            ST_Transform(api_tellzones.point, 2163),
            ST_Transform(ST_GeomFromText($1, 4326), 2163)
          ) * 3.28084 AS distance,
          api_networks.id AS api_networks_id,
          api_networks.name AS api_networks_name
      FROM api_tellzones
      LEFT OUTER JOIN api_networks_tellzones ON api_networks_tellzones.tellzone_id = api_tellzones.id
      LEFT OUTER JOIN api_networks ON api_networks.id = api_networks_tellzones.network_id
      WHERE ST_DWithin(ST_Transform(api_tellzones.point, 2163), ST_Transform(ST_GeomFromText($1, 4326), 2163), 91.44)
      """,
      ["POINT(#{longitude} #{latitude})"],
      []
    ) do
      {:ok, %{num_rows: 0}} -> get_radar_post_2(user_location)
      {:ok, %{rows: rows, num_rows: _}} -> get_radar_post_3(rows)
    end
  end

  def get_radar_post_2(user_location) do
    {longitude, latitude} = user_location.point.coordinates
    case SQL.query(
      Repo,
      """
      SELECT
          api_tellzones.id AS api_tellzones_id,
          api_tellzones.name AS api_tellzones_name,
          ST_Distance(
            ST_Transform(api_tellzones.point, 2163),
            ST_Transform(ST_GeomFromText($1, 4326), 2163)
          ) * 3.28084 AS distance,
          api_networks.id AS api_networks_id,
          api_networks.name AS api_networks_name
      FROM api_tellzones
      LEFT OUTER JOIN api_networks_tellzones ON api_networks_tellzones.tellzone_id = api_tellzones.id
      LEFT OUTER JOIN api_networks ON api_networks.id = api_networks_tellzones.network_id
      WHERE
          api_networks_tellzones.network_id IN (
              SELECT DISTINCT api_networks.id
              FROM api_tellzones
              INNER JOIN api_networks_tellzones ON api_networks_tellzones.tellzone_id = api_tellzones.id
              INNER JOIN api_networks ON api_networks.id = api_networks_tellzones.network_id
              WHERE ST_DWithin(
                ST_Transform(api_tellzones.point, 2163),
                ST_Transform(ST_GeomFromText($1, 4326), 2163),
                8046.72
              )
              ORDER BY api_networks.id ASC
          )
          AND
          api_tellzones.status = $2
      """,
      ["POINT(#{longitude} #{latitude})", "Public"],
      []
    ) do
      {:ok, %{num_rows: 0}} -> []
      {:ok, %{rows: rows, num_rows: _}} -> get_radar_post_3(rows)
    end
  end

  def get_radar_post_3(rows) do
    tellzones = Enum.map(
      rows,
      fn(row) ->
        %{
          "id" => Enum.at(row, 0),
          "name" => Enum.at(row, 1),
          "distance" => Enum.at(row, 2),
          "network" => %{
            "id" => Enum.at(row, 3),
            "name" => Enum.at(row, 4)
          }
        }
      end
    )
    Enum.sort(tellzones, &(&1["distance"] < &2["distance"]))
    # sort networks by +name, -id
    # sort tellzones by +distance, -id
  end
end
