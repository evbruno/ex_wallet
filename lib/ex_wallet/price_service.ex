defmodule ExWallet.PriceService do
  @base_api "https://api.binance.com/api/v3/ticker/price?symbol="

  alias ExWallet.SimpleCache

  def ethereum_usd do
    cached_price("ETHUSDT")
  end

  def bitcoin_usd do
    cached_price("BTCUSDT")
  end

  def solana_usd do
    cached_price("SOLUSDT")
  end

  defp cached_price(symbol) do
    p = SimpleCache.get_or_update(symbol, fn -> fetch_price(symbol) |> elem(1) end)
    {:ok, p}
  end

  defp fetch_price(symbol) do
    url = @base_api <> symbol
    req = Finch.build(:get, url)

    case Finch.request(req, ExWallet.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, %{"price" => price_str}} = Jason.decode(body)
        {price, _} = Float.parse(price_str)
        {:ok, price}

      {:ok, %Finch.Response{status: status}} when status in 400..599 ->
        {:error, "Failed to fetch price for #{symbol}: HTTP #{status}"}

      {:error, reason} ->
        {:error, "Failed to fetch price for #{symbol}: #{reason}"}
    end
  end
end
