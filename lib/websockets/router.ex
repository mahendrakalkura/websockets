defmodule WebSockets.Router do
  @behaviour :cowboy_websocket_handler

  @moduledoc ""

  alias Ecto.Query, as: Query
  alias WebSockets.Clients, as: Clients
  alias WebSockets.Repo, as: Repo
  alias WebSockets.User, as: User

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

  def websocket_handle({:text, content}, req, state) do
    case JSX.decode(content) do
      {:ok, %{"subject" => subject, "body" => body}} ->
        websocket_handle_(subject, body, req, state)
      _ ->
        {:ok, req, state}
    end
  end

  def websocket_handle_("users", body, req, state) do
    Repo.all(from user in User, select: user)
    Clients.insert(to_string(:erlang.pid_to_list(self())), body)
    {:ok, message} = JSX.encode(%{subject: "users", body: true})
    {:reply, {:text, message}, req, state}
  end

  def websocket_handle_("users_locations_post", body, req, state) do
    Repo.all(from user in User, select: user)
    {:ok, message} = JSX.encode(%{subject: "users_locations_post", body: body})
    Enum.each(
      Clients.select_all(),
      fn({key, _}) ->
        Repo.all(from user in User, select: user)
        send(
          :erlang.list_to_pid(to_char_list(key)),
          {"users_locations_get", body}
        )
      end
    )
    {:reply, {:text, message}, req, state}
  end

  def websocket_handle_(_subject, _body, req, state) do
    {:ok, req, state}
  end

  def websocket_info({"users_locations_get", body}, req, state) do
    {:ok, message} = JSX.encode(%{subject: "users_locations_get", body: body})
    {:reply, {:text, message}, req, state}
  end

  def websocket_info(_info, req, state) do
    {:ok, req, state}
  end

  def websocket_terminate(_reason, _req, _state) do
    Clients.delete(to_string(:erlang.pid_to_list(self())))
    :ok
  end
end
