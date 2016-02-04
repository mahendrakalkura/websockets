defmodule WebSockets.Clients do
  @moduledoc false

  require Kernel

  use GenServer

  def start_link() do
    GenServer.start_link(__MODULE__, [], [])
  end

  def init([]) do
    :ets.new(:ets, [:named_table, :public, :set])
    {:ok, :undefined_state}
  end

  def select_all() do
    :ets.tab2list(:ets)
  end

  def select_one(key) do
    case :ets.match_object(:ets, {key, :_}) do
      [{_, value}] -> value
      [] -> 0
    end
  end

  def select_any(value) do
    Enum.map(:ets.match_object(:ets, {:_, value}), fn({key, _}) -> key end)
  end

  def insert(key, value) do
    :ets.insert(:ets, {key, value})
  end

  def delete(item) when Kernel.is_pid(item) do
    :ets.match_delete(:ets, {item, :_})
  end

  def delete(item) when Kernel.is_bitstring(item) do
    :ets.match_delete(:ets, {:_, item})
  end
end
