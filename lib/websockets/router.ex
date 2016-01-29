defmodule WebSockets.Router do
  @behaviour :cowboy_websocket_handler

  @moduledoc ""

  alias WebSockets.Clients, as: Clients
  alias WebSockets.Repo, as: Repo

  import Ecto.Adapters.SQL

  require Application
  require Enum
  require ExSentry
  require JSX
  require Kernel
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
    self
      |> :erlang.pid_to_list()
      |> Kernel.to_string()
      |> Clients.delete()
    :ok
  end

  def process("messages", body, req, state) do
    {:ok, message} = JSX.encode(%{subject: "messages", body: body})
    {:reply, {:text, message}, req, state}
  end

  def process("users", body, req, state) do
    case System.cmd(
      Application.get_env(:websockets, :python),
      [
        Application.get_env(:websockets, :django),
        "user",
        body,
      ],
      stderr_to_stdout: false
    ) do
      {"True", 0} ->
        self
          |> :erlang.pid_to_list()
          |> Kernel.to_string()
          |> Clients.insert(body)
        {:ok, message} = JSX.encode(%{subject: "users", body: true})
        {:reply, {:text, message}, req, state}
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
