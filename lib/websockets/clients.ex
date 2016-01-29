defmodule WebSockets.Clients do
  @moduledoc ""

  use GenServer

  def start_link(state, options \\ []) do
    GenServer.start_link(__MODULE__, state, options)
  end

  def init([]) do
    :ets.new(:ets, [:named_table, :public, :set])
    {:ok, :undefined_state}
  end

  def select_all() do
    :ets.tab2list(:ets)
  end

  def select_one(key: key) do
    case :ets.match_object(:ets, {key, :"$1"}) do
      [{_, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end

  def select_one(value: value) do
    case :ets.match_object(:ets, {:"$1", value}) do
      [{key, _}] -> {:ok, key}
      [] -> {:error, :not_found}
    end
  end

  def insert(key, value) do
    :ets.insert(:ets, {key, value})
  end

  def delete(key: key) do
    :ets.match_delete(:ets, {key, :_})
  end

  def delete(value: value) do
    :ets.match_delete(:ets, {:_, value})
  end
end
