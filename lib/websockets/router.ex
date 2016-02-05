defmodule WebSockets.Router do
  @moduledoc false

  @behaviour :cowboy_websocket_handler

  alias Comeonin.Bcrypt, as: Bcrypt
  alias WebSockets.Clients, as: Clients
  alias WebSockets.Repo, as: Repo
  alias WebSockets.Repo.User, as: User
  alias WebSockets.Utilities, as: Utilities

  require Application
  require Integer
  require JSX
  require Kernel
  require String

  def init(_protocol, _request, _options) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_protocol, request, _options) do
    {:ok, request, :undefined_state}
  end

  def websocket_handle({:text, "ping"}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "In", id, "ping") end)
    Kernel.spawn(fn() -> Utilities.log("Router", "Out", id, "pong") end)
    {:reply, {:text, "pong"}, request, state}
  end

  def websocket_handle({:text, "pong"}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "In", id, "pong") end)
    Kernel.spawn(fn() -> Utilities.log("Router", "Out", id, "ping") end)
    {:reply, {:text, "ping"}, request, state}
  end

  def websocket_handle({:text, contents}, request, state) do
    case JSX.decode(contents) do
      {:ok, %{"subject" => subject, "body" => body}} ->
        handle(subject, body, request, state)
      {:ok, _} ->
        Kernel.spawn(fn() -> Utilities.log("websocket_handle()", %{"contents" => contents}) end)
        {:ok, request, state}
      {:error, reason} ->
        Kernel.spawn(fn() -> Utilities.log("websocket_handle()", %{"contents" => contents, "reason" => reason}) end)
        {:ok, request, state}
    end
  end

  def websocket_info({subject, body, action}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "Out", id, subject) end)
    {:ok, message} = JSX.encode(%{"subject" => subject, "body" => body, "action" => action})
    {:reply, {:text, message}, request, state}
  end

  def websocket_info({subject, body}, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "Out", id, subject) end)
    {:ok, message} = JSX.encode(%{"subject" => subject, "body" => body})
    {:reply, {:text, message}, request, state}
  end

  def websocket_info(contents, request, state) do
    Kernel.spawn(fn() -> Utilities.log("websocket_info()", %{"contents" => contents}) end)
    {:ok, request, state}
  end

  def websocket_terminate(reason, _request, _state) do
    Clients.delete(Kernel.self())
    terminate(reason)
    :ok
  end

  def handle("messages", body, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "In", id, "messages") end)
    Kernel.spawn(fn() -> Enum.each(Clients.select_all(), fn({key, _}) -> Kernel.send(key, {"messages", body}) end) end)
    # TODO
    {:ok, request, state}
  end

  def handle("users", body, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "In", id, "users") end)
    users_1(body, request, state)
  end

  def handle("users_locations_post", body, request, state) do
    id = Utilities.get_id(Kernel.self())
    Kernel.spawn(fn() -> Utilities.log("Router", "In", id, "users_locations_post") end)
    Kernel.spawn(
      fn() -> Enum.each(Clients.select_all(), fn({key, _}) -> Kernel.send(key, {"users_locations_post", body}) end) end
    )
    # TODO
    {:ok, request, state}
  end

  def handle(subject, body, request, state) do
    Kernel.spawn(fn() -> Utilities.log("handle()", %{"subject" => subject, "body" => body}) end)
    {:ok, request, state}
  end

  def terminate({:error, :closed}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:error, :closed}"}) end)
  end

  def terminate({:error, :badencoding}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:error, :badencoding}"}) end)
  end

  def terminate({:error, :badframe}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:error, :badframe}"}) end)
  end

  def terminate({:error, atom}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:error, #{atom}}"}) end)
  end

  def terminate({:normal, :shutdown}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:normal, :shutdown}"}) end)
  end

  def terminate({:normal, :timeout}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:normal, :timeout}"}) end)
  end

  def terminate({:remote, :closed}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "{:remote, :closed}"}) end)
  end

  def terminate({:remote, prefix, suffix}) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => %{"prefix" => prefix, "suffix" => suffix}}) end)
  end

  def terminate(_) do
    Kernel.spawn(fn() -> Utilities.log("terminate()", %{"reason" => "_"}) end)
  end

  def users_1(token, request, state) do
    case String.split(token, Application.get_env(:websockets, :separator), parts: 2, trim: true) do
      [id, hash] ->
        users_2(id, hash, request, state)
      _ ->
        Kernel.send(Kernel.self(), {"users", false})
        {:ok, request, state}
    end
  end

  def users_2(id, hash, request, state) do
    if Bcrypt.checkpw(id <> Application.get_env(:websockets, :secret), hash) do
      users_3(id, request, state)
    else
      Kernel.send(Kernel.self(), {"users", false})
      {:ok, request, state}
    end
  end

  def users_3(id, request, state) do
    case Integer.parse(id) do
      {id, _} ->
        users_4(id, request, state)
      _ ->
        Kernel.send(Kernel.self(), {"users", false})
        {:ok, request, state}
    end
  end

  def users_4(id, request, state) do
    case Repo.get(User, id) do
      nil ->
        Kernel.send(Kernel.self(), {"users", false})
        {:ok, request, state}
      user ->
        Clients.insert(Kernel.self(), user.id)
        Kernel.send(Kernel.self(), {"users", true})
        {:ok, request, state}
    end
  end
end
