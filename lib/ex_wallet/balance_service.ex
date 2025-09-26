defmodule ExWallet.BalanceService do
  alias ExWallet.Cycler
  require Logger

  def init_providers do
    :ok = ExWallet.BalanceService.Bitcoin.init_providers()
    :ok = ExWallet.BalanceService.Ethereum.init_providers()
    # :ok = ExWallet.BalanceService.Solana.init_providers()
    :ok
  end

  defdelegate bitcoin_balance(address), to: ExWallet.BalanceService.Bitcoin, as: :balance
  defdelegate ethereum_balance(address), to: ExWallet.BalanceService.Ethereum, as: :balance
  defdelegate solana_balance(address), to: ExWallet.BalanceService.Solana, as: :balance
end

defmodule ExWallet.BalanceService.Bitcoin do
  require Logger
  alias ExWallet.Cycler

  def init_providers do
    btc_providers = ["blockcypher", "blockchain", "blockstream", "mempool"]

    case Cycler.start_link(:btc, btc_providers) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        Logger.debug("BTC Cycler already started")
        :ok

      {:error, reason} ->
        Logger.error("Failed to start BTC Cycler: #{inspect(reason)}")
        :abort
    end
  end

  @max_cycles 8

  defp next_provider, do: Cycler.next(:btc)

  def balance(address) do
    Logger.debug("Fetching BTC balance for address #{address}")

    ExWallet.TelemetryUtils.measure(
      [:balance_load, :btc],
      fn -> balance_try(address, @max_cycles) end
    )
  end

  # let's not fail for now
  # defp balance_try(_address, 0), do: {:error, "All BTC providers failed"}
  defp balance_try(_address, t) when t <= 0 do
    Logger.debug("All BTC providers failed")
    {:ok, nil}
  end

  defp balance_try(address, t) do
    provider = next_provider()

    case balance_impl(address, provider) do
      {:ok, btc} ->
        {:ok, btc}

      {:error, reason} ->
        Logger.debug(
          "BTC provider #{provider} failed: #{inspect(reason)}. Trying next provider..."
        )

        Process.sleep(500)
        balance_try(address, t - 1)
    end
  end

  def balance_impl(address, "blockcypher") do
    Logger.debug("Fetching BTC balance from BlockCypher for address #{address}")

    url = "https://api.blockcypher.com/v1/btc/main/addrs/#{address}/balance"
    req = Finch.build(:get, url)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, %{"final_balance" => satoshis}} = Jason.decode(body)
        btc = satoshis / 1.0e8
        {:ok, btc}

      {_, reason} ->
        {:error, "Failed to fetch Bitcoin balance: #{inspect(reason)}"}
    end
  end

  def balance_impl(address, "blockchain") do
    Logger.debug("Fetching BTC balance from Blockchain for address #{address}")

    url = "https://blockchain.info/q/addressbalance/#{address}"
    req = Finch.build(:get, url)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        satoshis = String.to_integer(body)
        btc = satoshis / 1.0e8
        {:ok, btc}

      {_, reason} ->
        {:error, "Failed to fetch Bitcoin balance: #{inspect(reason)}"}
    end
  end

  def balance_impl(address, "blockstream") do
    Logger.debug("Fetching BTC balance from Blockstream for address #{address}")

    url = "https://blockstream.info/api/address/#{address}"
    req = Finch.build(:get, url)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, %{"chain_stats" => %{"funded_txo_sum" => satoshis}}} = Jason.decode(body)
        btc = satoshis / 1.0e8
        {:ok, btc}

      {_, reason} ->
        {:error, "Failed to fetch Bitcoin balance: #{inspect(reason)}"}
    end
  end

  def balance_impl(address, "mempool") do
    Logger.debug("Fetching BTC balance from Mempool for address #{address}")

    url = "https://mempool.space/api/address/#{address}"
    req = Finch.build(:get, url)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, %{"chain_stats" => %{"funded_txo_sum" => satoshis}}} = Jason.decode(body)
        btc = satoshis / 1.0e8
        {:ok, btc}

      {_, reason} ->
        {:error, "Failed to fetch Bitcoin balance: #{inspect(reason)}"}
    end
  end
end

defmodule ExWallet.BalanceService.Ethereum do
  require Logger
  alias ExWallet.Cycler

  def init_providers do
    eth_providers = ["ethereumex", "ethereum-rpc", "blockscout"]

    case Cycler.start_link(:eth, eth_providers) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        Logger.debug("ETH Cycler already started")
        :ok

      {:error, reason} ->
        Logger.error("Failed to start ETH Cycler: #{inspect(reason)}")
        :abort
    end
  end

  @max_cycles 6

  defp next_provider, do: Cycler.next(:eth)

  def balance(address) do
    Logger.debug("Fetching ETH balance for address #{address}")

    ExWallet.TelemetryUtils.measure(
      [:balance_load, :eth],
      fn -> balance_try(address, @max_cycles) end
    )
  end

  defp balance_try(address, t) do
    provider = next_provider()

    case balance_impl(address, provider) do
      {:ok, eth} ->
        {:ok, eth}

      {:error, reason} ->
        Logger.debug(
          "ETH provider #{provider} failed: #{inspect(reason)}. Trying next provider..."
        )

        Process.sleep(250)
        balance_try(address, t - 1)
    end
  end

  defp balance_impl(address, "ethereumex") do
    Logger.debug("Fetching ETH balance from Ethereumex for address #{address}")

    case Ethereumex.HttpClient.eth_get_balance(address, "latest") do
      {:ok, bal_hex} ->
        val = String.to_integer(String.trim_leading(bal_hex, "0x"), 16)
        eth = val / 1.0e18
        {:ok, eth}

      {_, reason} ->
        {:error, reason}
    end
  end

  defp balance_impl(address, "ethereum-rpc") do
    Logger.debug("Fetching ETH balance from Ethereum RPC for address #{address}")

    url = "https://ethereum-rpc.publicnode.com"

    body =
      %{
        "jsonrpc" => "2.0",
        "method" => "eth_getBalance",
        "params" => [address, "latest"],
        "id" => 1
      }
      |> Jason.encode!()

    headers = [{"Content-Type", "application/json"}]
    req = Finch.build(:post, url, headers, body)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, %{"result" => bal_hex}} = Jason.decode(body)
        val = String.to_integer(String.trim_leading(bal_hex, "0x"), 16)
        eth = val / 1.0e18
        {:ok, eth}

      {_, reason} ->
        {:error, reason}
    end
  end

  defp balance_impl(address, "blockscout") do
    Logger.debug("Fetching ETH balance from Blockscout for address #{address}")

    url = "https://eth.blockscout.com/api?module=account&action=balance&address=#{address}"

    req = Finch.build(:get, url)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, %{"result" => bal_str}} = Jason.decode(body)
        val = String.to_integer(bal_str)
        eth = val / 1.0e18
        {:ok, eth}

      {_, reason} ->
        {:error, reason}
    end
  end
end

defmodule ExWallet.BalanceService.Solana do
  require Logger

  def balance(address) do
    Logger.debug("Fetching SOL balance for address #{address}")

    ExWallet.TelemetryUtils.measure(
      [:balance_load, :sol],
      fn -> balance_impl(address) end
    )
  end

  defp balance_impl(address) do
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

      {_, reason} ->
        {:error, reason}
    end
  end
end
