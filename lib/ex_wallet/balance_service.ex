defmodule ExWallet.BalanceService do
  require Logger

  def ethereum_balance(address) do
    Logger.debug("Fetching ETH balance for address #{address}")

    case Ethereumex.HttpClient.eth_get_balance(address, "latest") do
      {:ok, bal_hex} ->
        val = String.to_integer(String.trim_leading(bal_hex, "0x"), 16)
        eth = val / 1.0e18
        {:ok, eth}

      # avoid returning 0.0 for empty balances
      {:error, reason} ->
        Logger.debug("Failed to fetch ETH balance for #{address}: #{inspect(reason)}")
        {:ok, nil}
    end

    # {:ok, bal_hex} = Ethereumex.HttpClient.eth_get_balance(address, "latest")
    # val = String.to_integer(String.trim_leading(bal_hex, "0x"), 16)
    # eth = val / 1.0e18
    # {:ok, eth}
  end

  @btc_providers ["blockcypher", "blockchain", "blockstream", "mempool"]

  # def bitcoin_balance([address, type]) when type in [:legacy, :nested_segwit, :native_segwit] do
  #   IO.puts("AFetching BTC balance for address #{address} of type #{type}")
  #   bitcoin_balance_try(address, type, length(@btc_providers) * 2)
  # end

  def bitcoin_balance(address, type \\ :legacy) do
    # IO.puts("BFetching BTC balance for address #{address} of type #{type}")
    bitcoin_balance_try(address, type, length(@btc_providers) * 2)
  end

  defp bitcoin_balance_try(_address, _type, 0), do: {:error, "All BTC providers failed"}

  defp bitcoin_balance_try(address, type, t) do
    provider = next_btc_provider(type)

    case bitcoin_balance_impl(address, provider) do
      {:ok, btc} ->
        {:ok, btc}

      {:error, reason} ->
        Logger.debug(
          "BTC #{type} provider #{provider} failed: #{reason}. Trying next provider..."
        )

        Process.sleep(500)
        bitcoin_balance_try(address, type, t - 1)
    end
  end

  defp next_btc_provider(type) do
    idx = :persistent_term.get(:btc_provider_idx, 0)

    idx =
      case type do
        :legacy -> idx
        :nested_segwit -> rem(idx + 1, length(@btc_providers))
        :native_segwit -> rem(idx + 2, length(@btc_providers))
      end

    n_idx = rem(idx + 1, length(@btc_providers))
    :persistent_term.put(:btc_provider_idx, n_idx)

    Enum.at(@btc_providers, idx)
  end

  def bitcoin_balance_impl(address, "blockcypher") do
    Logger.debug("Fetching BTC balance from BlockCypher for address #{address}")

    url = "https://api.blockcypher.com/v1/btc/main/addrs/#{address}/balance"
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
        {:error, "Failed to fetch Bitcoin balance: #{inspect(reason)}"}
    end
  end

  def bitcoin_balance_impl(address, "blockchain") do
    Logger.debug("Fetching BTC balance from Blockchain for address #{address}")

    url = "https://blockchain.info/q/addressbalance/#{address}"
    req = Finch.build(:get, url)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        satoshis = String.to_integer(body)
        btc = satoshis / 1.0e8
        {:ok, btc}

      {:ok, %Finch.Response{status: status, body: body}} ->
        {:error, "Failed to fetch Bitcoin balance: #{status} => #{body}"}

      {:error, reason} ->
        {:error, "Failed to fetch Bitcoin balance: #{reason}"}
    end
  end

  def bitcoin_balance_impl(address, "blockstream") do
    Logger.debug("Fetching BTC balance from Blockstream for address #{address}")

    url = "https://blockstream.info/api/address/#{address}"
    req = Finch.build(:get, url)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, %{"chain_stats" => %{"funded_txo_sum" => satoshis}}} = Jason.decode(body)
        btc = satoshis / 1.0e8
        {:ok, btc}

      {:ok, %Finch.Response{status: status}} when status in 400..599 ->
        {:error, "Failed to fetch Bitcoin balance: HTTP #{status}"}

      {:error, reason} ->
        {:error, "Failed to fetch Bitcoin balance: #{reason}"}
    end
  end

  def bitcoin_balance_impl(address, "mempool") do
    Logger.debug("Fetching BTC balance from Mempool for address #{address}")

    url = "https://mempool.space/api/address/#{address}"
    req = Finch.build(:get, url)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, %{"chain_stats" => %{"funded_txo_sum" => satoshis}}} = Jason.decode(body)
        btc = satoshis / 1.0e8
        {:ok, btc}

      {:ok, %Finch.Response{status: status}} when status in 400..599 ->
        {:error, "Failed to fetch Bitcoin balance: HTTP #{status}"}

      {:error, reason} ->
        {:error, "Failed to fetch Bitcoin balance: #{inspect(reason)}"}
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
