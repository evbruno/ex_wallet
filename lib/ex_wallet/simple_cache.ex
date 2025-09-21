defmodule ExWallet.SimpleCache do
  use Agent
  require Logger

  @expiry 30

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, {value, :os.system_time(:second)}))
  end

  def get_or_update(key, fun) do
    Agent.get_and_update(__MODULE__, fn cache ->
      now = :os.system_time(:second)

      case Map.get(cache, key) do
        {value, ts} when now - ts < @expiry ->
          Logger.debug("Cache hit for key #{inspect(key)}")
          {value, cache}

        _ ->
          new_value = fun.()
          Logger.debug("Cache miss for key #{inspect(key)}; updating cache")
          {new_value, Map.put(cache, key, {new_value, now})}
      end
    end)
  end
end
