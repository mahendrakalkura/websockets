defmodule WebSockets.Clients do
  @moduledoc ""

  use GenServer

  def start_link(state, opts \\ []) do
    GenServer.start_link(__MODULE__, state, opts)
  end

  def init([]) do
    :ets.new(:ets, [:named_table, :public, :set])
    {:ok, :undefined_state}
  end

  def select_all() do
    :ets.tab2list(:ets)
  end

  def select_one(key) do
    case :ets.lookup(:ets, key) do
      [{_, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end

  def insert(key, value) do
    :ets.insert(:ets, {key, value})
  end

  def delete(key) do
    :ets.match_delete(:ets, {key, :_})
  end
end
