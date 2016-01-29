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
    try do
      case JSX.decode(contents) do
        {:ok, %{"subject" => subject, "body" => body}} ->
          process(subject, body, req, state)
        _ ->
          ExSentry.capture_message(
            "Invalid Contents", extra: %{"contents": contents}
          )
          {:ok, req, state}
      end
    rescue
      exception ->
        ExSentry.capture_exception(exception)
    end
  end

  def websocket_info({"users_locations_get", body}, req, state) do
    {:ok, message} = JSX.encode(%{subject: "users_locations_get", body: body})
    {:reply, {:text, message}, req, state}
  end

  def websocket_info(_info, req, state) do
    {:ok, req, state}
  end

  def websocket_terminate(_reason, _req, _state) do
    key = self
      |> :erlang.pid_to_list()
      |> Kernel.to_string()
    Clients.delete(key: key)
    :ok
  end

  def process("messages", body, req, state) do
    {:ok, message} = JSX.encode(%{subject: "messages", body: body})
    {:reply, {:text, message}, req, state}
  end

  def process("users", body, req, state) do
    [id, hash] = String.split(
      body, Application.get_env(:websockets, :separator), parts: 2
    )
    case Bcrypt.checkpw(
      id <> Application.get_env(:websockets, :secret), hash
    ) do
      true ->
        try do
          {id, _} = Integer.parse(id)
          {:ok, %{"rows": _rows, "num_rows": 1}} = SQL.query(
            Repo, "SELECT * FROM api_users WHERE id = $1", [id], []
          )
          self
            |> :erlang.pid_to_list()
            |> Kernel.to_string()
            |> Clients.insert(id)
          {:ok, message} = JSX.encode(%{subject: "users", body: true})
          {:reply, {:text, message}, req, state}
        rescue
          exception ->
            ExSentry.capture_exception(exception)
            {:ok, message} = JSX.encode(%{subject: "users", body: false})
            {:reply, {:text, message}, req, state}
        end
      _ ->
        {:ok, message} = JSX.encode(%{subject: "users", body: false})
        {:reply, {:text, message}, req, state}
    end
  end

  def process("users_locations_post", body, req, state) do
    {:ok, message} = JSX.encode(%{subject: "users_locations_post", body: body})
    Clients.select_all()
      |> Enum.each(
        fn({key, _}) ->
          key
            |> Kernel.to_char_list()
            |> :erlang.list_to_pid()
            |> Kernel.send({"users_locations_get", body})
        end
      )
    {:reply, {:text, message}, req, state}
  end

  def process(_subject, _body, req, state) do
    {:ok, req, state}
  end
end
