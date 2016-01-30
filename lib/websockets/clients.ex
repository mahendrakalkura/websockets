defmodule WebSockets.Clients do
  @moduledoc ""

  require Kernel

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

  def select_one(key) when Kernel.is_pid(key) do
    case :ets.match_object(:ets, {key, :_}) do
      [{_, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end

  def select_one(value) when Kernel.is_integer(value) do
    case :ets.match_object(:ets, {:_, value}) do
      [{key, _}] -> {:ok, key}
      [] -> {:error, :not_found}
    end
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
