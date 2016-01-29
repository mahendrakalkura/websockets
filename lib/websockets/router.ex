defmodule WebSockets.Router do
  @behaviour :cowboy_websocket_handler

  @moduledoc ""

  alias Comeonin.Bcrypt, as: Bcrypt
  alias Ecto.Adapters.SQL, as: SQL
  alias WebSockets.Clients, as: Clients
  alias WebSockets.Repo, as: Repo

  require Application
  require Enum
  require ExSentry
  require Integer
  require JSX
  require Kernel
  require String
  require System

  def init(_protocol, _req, _opts) do
    {:upgrade, :protocol, :cowboy_websocket}
  end

  def websocket_init(_protocol, req, _opts) do
    {:ok, req, :undefined_state}
  end

  def websocket_handle({:text, "ping"}, req, state) do
    {:reply, {:text, "pong"}, req, state}
  end

  def websocket_handle({:text, "pong"}, req, state) do
    {:reply, {:text, "ping"}, req, state}
  end

  def websocket_handle({:text, contents}, req, state) do
    websocket_handle({:text, contents}, JSX.decode(contents), req, state)
  end

  def websocket_handle({:text, _contents}, {:ok, %{"subject" => subject, "body" => body}}, req, state) do
    try do
      process(subject, body, req, state)
    rescue
      exception ->
        Kernel.spawn(fn -> ExSentry.capture_exception(exception, extra: %{"subject" => subject, "body" => body}) end)
        {:ok, req, state}
    end
  end

  def websocket_handle({:text, contents}, {:ok, _}, req, state) do
    Kernel.spawn(fn -> ExSentry.capture_message("Invalid Contents (#1)", extra: %{"contents" => contents}) end)
    {:ok, req, state}
  end

  def websocket_handle({:text, contents}, {:error, reason}, req, state) do
    Kernel.spawn(
      fn -> ExSentry.capture_message("Invalid Contents (#2)", extra: %{"contents" => contents, "reason" => reason}) end
    )
    {:ok, req, state}
  end

  def websocket_info({"messages", body}, req, state) do
    {:ok, message} = JSX.encode(%{"subject" => "messages", "body" => body})
    {:reply, {:text, message}, req, state}
  end

  def websocket_info({"users_locations_get", body}, req, state) do
    {:ok, message} = JSX.encode(%{"subject" => "users_locations_get", "body" => body})
    {:reply, {:text, message}, req, state}
  end

  def websocket_info(_contents, req, state) do
    {:ok, req, state}
  end

  def websocket_terminate(_reason, _req, _state) do
    Clients.delete(key: self |> :erlang.pid_to_list() |> Kernel.to_string())
    :ok
  end

  def process("messages", body, req, state) do
    {:ok, message} = JSX.encode(%{"subject" => "messages", "body" => body})
    Kernel.spawn(
      fn ->
        Clients.select_all()
          |> Enum.each(
            fn({key, _}) ->
              key |> Kernel.to_char_list() |> :erlang.list_to_pid() |> Kernel.send({"messages", body})
            end
          )
      end
    )
    {:reply, {:text, message}, req, state}
  end

  def process("users", body, req, state) do
    case String.split(body, Application.get_env(:websockets, :separator), parts: 2, trim: true) do
      [id, hash] ->
        if Bcrypt.checkpw(id <> Application.get_env(:websockets, :secret), hash) do
          {id, _} = Integer.parse(id)
          {:ok, %{rows: _rows, num_rows: 1}} = SQL.query(Repo, "SELECT * FROM api_users WHERE id = $1", [id], [])
          self |> :erlang.pid_to_list() |> Kernel.to_string() |> Clients.insert(id)
          {:ok, message} = JSX.encode(%{"subject" => "users", "body" => true})
          {:reply, {:text, message}, req, state}
        else
          {:ok, message} = JSX.encode(%{"subject" => "users", "body" => false})
          {:reply, {:text, message}, req, state}
        end
      _ ->
        {:ok, message} = JSX.encode(%{"subject" => "users", "body" => false})
        {:reply, {:text, message}, req, state}
    end
  end

  def process("users_locations_post", body, req, state) do
    {:ok, message} = JSX.encode(%{"subject" => "users_locations_post", "body" => body})
    Kernel.spawn(
      fn ->
        Clients.select_all()
          |> Enum.each(
            fn({key, _}) ->
              key |> Kernel.to_char_list() |> :erlang.list_to_pid() |> Kernel.send({"users_locations_get", body})
            end
          )
      end
    )
    {:reply, {:text, message}, req, state}
  end

  def process(subject, body, req, state) do
    Kernel.spawn(
      fn -> ExSentry.capture_message("Invalid Contents (#3)", extra: %{"subject" => subject, "body" => body}) end
    )
    {:ok, req, state}
  end
end
