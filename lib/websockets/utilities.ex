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

  def publish(exchange, routing_key, contents) do
    {:ok, connection} = Connection.open(Application.get_env(:websockets, :broker))
    {:ok, channel} = Channel.open(connection)
    {:ok, contents} = JSX.encode(contents)
    Basic.publish(channel, exchange, routing_key, contents)
  end

  def get_direction(string) do
    :io_lib.format("~-3s", [string])
  end

  def get_distance({a, b}, {c, d}) do
    Distance.to_ft(Vector.calculate(%{latitude: a, longitude: b}, %{latitude: c, longitude: d}).distance).value
  end

  def get_formatted_datetime(datetime) do
    {:ok, datetime} = DateTime.dump(datetime)
    Date.from(datetime)
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

  def get_radar_get(user, users) do
    users
    |> Enum.map(
      fn(u) ->
        distance = get_distance(
          {
            Enum.at(user["point"]["coordinates"], 0),
            Enum.at(user["point"]["coordinates"], 1),
          }, {
            Enum.at(u["point"]["coordinates"], 0),
            Enum.at(u["point"]["coordinates"], 1),
          }
        )
        group = cond do # REVIEW
          user["tellzone_id"] === u["tellzone_id"] -> 1
          distance <= 300.0 -> 1
          true -> 2
        end
        # REVIEW (settings.show_photo -> u.photo_original + u.photo_preview)
        # REVIEW (delete -> u.network_id, u.tellzone_id, u.point + u.settings)
        %{
          "id" => u["id"],
          "photo_original" => u["photo_original"],
          "photo_preview" => u["photo_preview"],
          "distance" => distance,
          "group" => group
        }
      end
    )
    |> Enum.sort(&(&1["distance"] < &2["distance"]))
    |> Enum.with_index()
    |> Enum.map(
      fn({user, position}) ->
        %{
          "hash" => user["id"],
          "items" => [user],
          "position" => position + 1
        }
      end
    )
  end

  def get_radar_post_1(user_location) do
    {longitude, latitude} = user_location.point.coordinates
    case SQL.query(
      Repo,
      """
      SELECT
          api_tellzones.id AS api_tellzones_id,
          api_tellzones.name AS api_tellzones_name,
          ST_Distance(ST_Transform(api_tellzones.point, 2163), ST_Transform(ST_GeomFromText($1, 4326), 2163)) * 3.28084 AS distance,
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
          ST_Distance(ST_Transform(api_tellzones.point, 2163), ST_Transform(ST_GeomFromText($1, 4326), 2163)) * 3.28084 AS distance,
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
              WHERE ST_DWithin(ST_Transform(api_tellzones.point, 2163), ST_Transform(ST_GeomFromText($1, 4326), 2163), 8046.72)
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

  def get_users(point, radius) do
    {longitude, latitude} = point.coordinates
    case SQL.query(
      Repo,
      """
      SELECT
          api_users_locations.network_id AS network_id,
          api_users_locations.tellzone_id AS tellzone_id,
          ST_AsGeoJSON(api_users_locations.point) AS point,
          api_users.id AS id,
          api_users.photo_original AS photo_original,
          api_users.photo_preview AS photo_preview,
          api_users_settings.key AS user_setting_key,
          api_users_settings.value AS user_setting_value
      FROM api_users_locations
      INNER JOIN (
          SELECT MAX(api_users_locations.id) AS id
          FROM api_users_locations
          WHERE api_users_locations.timestamp > NOW() - INTERVAL '1 minute'
          GROUP BY api_users_locations.user_id
      ) api_users_locations_ ON api_users_locations_.id = api_users_locations.id
      INNER JOIN api_users ON api_users.id = api_users_locations.user_id
      LEFT OUTER JOIN api_users_settings AS api_users_settings ON api_users_settings.user_id = api_users.id
      WHERE
          ST_DWithin(ST_Transform(ST_GeomFromText($1, 4326), 2163), ST_Transform(api_users_locations.point, 2163), $2)
          AND
          api_users_locations.is_casting IS TRUE
          AND
          api_users_locations.timestamp > NOW() - INTERVAL '1 minute'
          AND
          api_users.is_signed_in IS TRUE
          AND
          api_users_settings.key = 'show_photo'
      ORDER BY api_users_locations.user_id ASC
      """,
      ["POINT(#{longitude} #{latitude})", radius],
      []
    ) do
      {:ok, %{rows: rows}} -> get_users(rows)
    end
  end

  def get_users(users) do
    users
    |> Enum.map(
      fn(user) ->
        %{
          "network_id" => Enum.at(user, 0),
          "tellzone_id" => Enum.at(user, 1),
          "point" => Enum.at(
            user, 2
          )|>Poison.decode!,
          "id" => Enum.at(user, 3),
          "photo_original" => Enum.at(user, 4),
          "photo_preview" => Enum.at(user, 5),
          "setting_key" => Enum.at(user, 6),
          "settings_value" => Enum.at(user, 7),
        }
      end
    )
  end
end
