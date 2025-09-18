defmodule ExWallet.BalanceService do
  def ethereum_balance(address) do
    {:ok, bal_hex} = Ethereumex.HttpClient.eth_get_balance(address, "latest")
    val = String.to_integer(String.trim_leading(bal_hex, "0x"), 16)
    eth = val / 1.0e18
    {:ok, eth}
  end

  def bitcoin_balance(address) do
    # Using BlockCypher API (free tier)
    url = "https://api.blockcypher.com/v1/btc/main/addrs/#{address}/balance"
    # https://api.blockchair.com/bitcoin/dashboards/address/<BTC_ADDRESS> err 430?

    req = Finch.build(:get, url)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, %{"final_balance" => satoshis}} = Jason.decode(body)
        btc = satoshis / 1.0e8
        {:ok, btc}

      {:ok, %Finch.Response{status: status}} when status in 400..599 ->
        {:error, "Failed to fetch Bitcoin balance: HTTP #{status}"}

      {:error, reason} ->
        {:error, "Failed to fetch Bitcoin balance: #{reason}"}
    end
  end

  def solana_balance(address) do
    url = "https://api.mainnet-beta.solana.com"

    body = %{
      "jsonrpc" => "2.0",
      "id" => 1,
      "method" => "getBalance",
      "params" => [address]
    }

    headers = [{"Content-Type", "application/json"}]
    req = Finch.build(:post, url, headers, Jason.encode!(body))

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, %{"result" => %{"value" => lamports}}} = Jason.decode(body)
        sol = lamports / 1.0e9
        {:ok, sol}

      {:ok, %Finch.Response{status: status}} when status in 400..599 ->
        {:error, "Failed to fetch Solana balance: HTTP #{status}"}

      {:error, reason} ->
        {:error, "Failed to fetch Solana balance: #{reason}"}
    end
  end
end
