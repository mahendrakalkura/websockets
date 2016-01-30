defmodule WebSockets.Router do
  @moduledoc false

  @behaviour :cowboy_websocket_handler

  alias Comeonin.Bcrypt, as: Bcrypt
  alias Ecto.Adapters.SQL, as: SQL
  alias WebSockets.Clients, as: Clients
  alias WebSockets.Repo, as: Repo
  alias WebSockets.Utilities, as: Utilities

  require Application
  require Enum
  require ExSentry
  require Integer
  require JSX
  require Kernel
  require String
  require System

  def init(_protocol, _request, _options) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_protocol, request, _options) do
    {:ok, request, :undefined_state}
  end

  def websocket_handle({:text, "ping"}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn -> Utilities.log("Router", "In", id, "ping") end)
    Kernel.spawn(fn -> Utilities.log("Router", "Out", id, "pong") end)
    {:reply, {:text, "pong"}, request, state}
  end

  def websocket_handle({:text, "pong"}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn -> Utilities.log("Router", "In", id, "pong") end)
    Kernel.spawn(fn -> Utilities.log("Router", "Out", id, "ping") end)
    {:reply, {:text, "ping"}, request, state}
  end

  def websocket_handle({:text, contents}, request, state) do
    websocket_handle({:text, contents}, JSX.decode(contents), request, state)
  end

  def websocket_handle({:text, _contents}, {:ok, %{"subject" => subject, "body" => body}}, request, state) do
    process({subject, body}, request, state)
  end

  def websocket_handle({:text, contents}, {:ok, _}, request, state) do
    Kernel.spawn(
      fn -> ExSentry.capture_message("websocket_handle() - Invalid Contents", extra: %{"contents" => contents}) end
    )
    {:ok, request, state}
  end

  def websocket_handle({:text, contents}, {:error, reason}, request, state) do
    Kernel.spawn(
      fn ->
        ExSentry.capture_message(
          "websocket_handle() - Invalid Contents", extra: %{"contents" => contents, "reason" => reason}
        )
      end
    )
    {:ok, request, state}
  end

  def websocket_info({subject, body}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn -> Utilities.log("Router", "Out", id, subject) end)
    {:ok, message} = JSX.encode(%{"subject" => subject, "body" => body})
    {:reply, {:text, message}, request, state}
  end

  def websocket_info(contents, request, state) do
    Kernel.spawn(
      fn -> ExSentry.capture_message("websocket_info() - Invalid Contents", extra: %{"contents" => contents}) end
    )
    {:ok, request, state}
  end

  def websocket_terminate(reason, _request, _state) do
    Clients.delete(Kernel.self())
    Kernel.spawn(fn -> terminate(reason) end)
    :ok
  end

  def process({"messages", body}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn -> Utilities.log("Router", "In", id, "messages") end)
    Kernel.self() |> Kernel.send({"messages", body})
    Kernel.spawn(
      fn -> Clients.select_all() |> Enum.each(fn({key, _}) -> key |> Kernel.send({"messages", body}) end) end
    )
    {:ok, request, state}
  end

  def process({"users", body}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn -> Utilities.log("Router", "In", id, "users") end)
    process({:users_1, body}, request, state)
  end

  def process({:users_1, token}, request, state) do
    case String.split(token, Application.get_env(:websockets, :separator), parts: 2, trim: true) do
      [id, hash] -> process({:users_2, id, hash}, request, state)
      _ ->
        Kernel.self() |> Kernel.send({"users", false})
        {:ok, request, state}
    end
  end

  def process({:users_2, id, hash}, request, state) do
    if Bcrypt.checkpw(id <> Application.get_env(:websockets, :secret), hash) do
      process({:users_3, id}, request, state)
    else
      Kernel.self() |> Kernel.send({"users", false})
      {:ok, request, state}
    end
  end

  def process({:users_3, id}, request, state) do
    case Integer.parse(id) do
      {id, _} -> process({:users_4, id}, request, state)
      _ ->
        Kernel.self() |> Kernel.send({"users", false})
        {:ok, request, state}
    end
  end

  def process({:users_4, id}, request, state) do
    case SQL.query(Repo, "SELECT * FROM api_users WHERE id = $1", [id], []) do
      {:ok, %{rows: _rows, num_rows: 1}} ->
        Kernel.self() |> Clients.insert(id)
        Kernel.self() |> Kernel.send({"users", true})
        {:ok, request, state}
      _ ->
        Kernel.self() |> Kernel.send({"users", false})
        {:ok, request, state}
    end
  end

  def process({"users_locations_post", body}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn -> Utilities.log("Router", "In", id, "users_locations_post") end)
    Kernel.self() |> Kernel.send({"users_locations_post", body})
    Kernel.spawn(
      fn ->
        Clients.select_all() |> Enum.each(fn({key, _}) -> key |> Kernel.send({"users_locations_get", body}) end)
      end
    )
    {:ok, request, state}
  end

  def process({subject, body}, request, state) do
    Kernel.spawn(
      fn ->
        ExSentry.capture_message("process() - Invalid Contents", extra: %{"subject" => subject, "body" => body})
      end
    )
    {:ok, request, state}
  end

  def terminate({:error, :closed}) do
    Kernel.spawn(fn -> ExSentry.capture_message("terminate()", extra: %{"reason" => "{:error, :closed}"}) end)
  end

  def terminate({:error, :badencoding}) do
    Kernel.spawn(fn -> ExSentry.capture_message("terminate()", extra: %{"reason" => "{:error, :badencoding}"}) end)
  end

  def terminate({:error, :badframe}) do
    Kernel.spawn(fn -> ExSentry.capture_message("terminate()", extra: %{"reason" => "{:error, :badframe}"}) end)
  end

  def terminate({:error, atom}) do
    Kernel.spawn(fn -> ExSentry.capture_message("terminate()", extra: %{"reason" => "{:error, #{atom}}"}) end)
  end

  def terminate({:normal, :shutdown}) do
    Kernel.spawn(fn -> ExSentry.capture_message("terminate()", extra: %{"reason" => "{:normal, :shutdown}"}) end)
  end

  def terminate({:normal, :timeout}) do
    Kernel.spawn(fn -> ExSentry.capture_message("terminate()", extra: %{"reason" => "{:normal, :timeout}"}) end)
  end

  def terminate({:remote, :closed}) do
    Kernel.spawn(fn -> ExSentry.capture_message("terminate()", extra: %{"reason" => "{:remote, :closed}"}) end)
  end

  def terminate({:remote, prefix, suffix}) do
    Kernel.spawn(
      fn ->
        ExSentry.capture_message("terminate()", extra: %{"reason" => %{"prefix" => prefix, "suffix" => suffix}})
      end
    )
  end

  def terminate(_) do
    Kernel.spawn(fn -> ExSentry.capture_message("terminate()", extra: %{"reason" => "_"}) end)
  end
end
