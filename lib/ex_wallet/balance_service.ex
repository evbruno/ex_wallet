defmodule ExWallet.BalanceService do
  alias ExWallet.Cycler

  require Logger

  def init_providers do
    :ok = ExWallet.BalanceService.Bitcoin.init_providers()
    :ok = ExWallet.BalanceService.Ethereum.init_providers()
    :ok = ExWallet.BalanceService.Solana.init_providers()
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
    btc_providers = [
      # "blockcypher",
      "blockchain",
      "blockstream",
      "mempool",
      "mempool-de",
      "3xpl-sandbox",
      "blockonomics"
    ]

    # btc_providers =
    #   if Application.get_env(:ex_wallet, :api_key_3xpl) do
    #     btc_providers
    #     # ++ ["3xpl-api"]
    #   else
    #     btc_providers
    #   end

    btc_providers =
      if Application.get_env(:ex_wallet, :blockonomics_api_key) do
        btc_providers
      else
        List.delete(btc_providers, "blockonomics")
      end

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

  @max_cycles 12

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
        :telemetry.execute(
          [:ex_wallet, :wallet, :balance_load, :btc, :success],
          %{count: 1},
          %{provider: provider}
        )

        {:ok, btc}

      {:error, reason} ->
        Logger.debug(
          "BTC provider #{provider} failed: #{inspect(reason)}. Trying next provider..."
        )

        :telemetry.execute(
          [:ex_wallet, :wallet, :balance_load, :btc, :error],
          %{count: 1},
          %{provider: provider}
        )

        sleep_rand_time = :rand.uniform(1_000)
        Process.sleep(sleep_rand_time)

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

  def balance_impl(address, "mempool-de") do
    Logger.debug("Fetching BTC balance from Mempool for address #{address}")

    url = "https://mempool.emzy.de/api/address/#{address}"
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

  def balance_impl(address, "3xpl-sandbox") do
    Logger.debug("Fetching BTC balance from 3xpl-sandbox for address #{address}")

    url = "https://sandbox-api.3xpl.com/bitcoin/address/#{address}?data=balances"

    xpl_api_req(url, "3xpl-sandbox")
  end

  def balance_impl(address, "3xpl-api") do
    Logger.debug("Fetching BTC balance from 3xpl-api for address #{address}")
    token = Application.fetch_env!(:ex_wallet, :api_key_3xpl)
    url = "https://api.3xpl.com/bitcoin/address/#{address}?data=balances&token=#{token}"

    xpl_api_req(url, "3xpl-api")
  end

  def balance_impl(address, "blockonomics") do
    Logger.debug("Fetching BTC balance from Blockonomics for address #{address}")

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{Application.fetch_env!(:ex_wallet, :blockonomics_api_key)}"}
    ]

    url = "https://www.blockonomics.co/api/balance?addr=#{address}"
    req = Finch.build(:get, url, headers)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        with {:ok, %{"response" => [%{"confirmed" => satoshis}]}} <- Jason.decode(body) do
          # satoshis = String.to_integer(satoshis)
          btc = satoshis / 1.0e8
          {:ok, btc}
        else
          error ->
            {:error, "Failed to decode Blockonomics response: #{inspect(error)}"}
        end

      {_, reason} ->
        {:error, "Failed to fetch Bitcoin balance: #{inspect(reason)}"}
    end
  end

  defp xpl_api_req(url, provider) do
    req = Finch.build(:get, url)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        with {:ok,
              %{
                "data" => %{
                  "balances" => %{"bitcoin-main" => %{"bitcoin" => %{"balance" => satoshis}}}
                }
              }} <- Jason.decode(body) do
          satoshis = String.to_integer(satoshis)
          btc = satoshis / 1.0e8
          {:ok, btc}
        else
          error ->
            {:error, "Failed to decode #{provider} response: #{inspect(error)}"}
        end

      {_, reason} ->
        {:error, "Failed to fetch Bitcoin balance: #{inspect(reason)}"}
    end
  end
end

defmodule ExWallet.BalanceService.Ethereum do
  require Logger
  alias ExWallet.Cycler

  def init_providers do
    eth_providers = ["ethereumex", "ethereum-rpc", "blockscout", "blockcypher"]

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

  # let's not fail for now
  defp balance_try(_address, t) when t <= 0 do
    Logger.debug("All ETH providers failed")
    {:ok, nil}
  end

  defp balance_try(address, t) do
    provider = next_provider()

    case balance_impl(address, provider) do
      {:ok, eth} ->
        :telemetry.execute(
          [:ex_wallet, :wallet, :balance_load, :eth, :success],
          %{count: 1},
          %{provider: provider}
        )

        {:ok, eth}

      {:error, reason} ->
        Logger.debug(
          "ETH provider #{provider} failed: #{inspect(reason)}. Trying next provider..."
        )

        :telemetry.execute(
          [:ex_wallet, :wallet, :balance_load, :eth, :error],
          %{count: 1},
          %{provider: provider}
        )

        sleep_rand_time = :rand.uniform(500)
        Process.sleep(sleep_rand_time)

        balance_try(address, t - 1)
    end
  end

  def balance_impl(address, "blockcypher") do
    Logger.debug("Fetching ETH balance from BlockCypher for address #{address}")

    url = "https://api.blockcypher.com/v1/eth/main/addrs/#{address}/balance"
    req = Finch.build(:get, url)

    Finch.request(req, ExWallet.Finch)
    |> case do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, %{"final_balance" => bal}} = Jason.decode(body)
        eth = bal / 1.0e18
        {:ok, eth}

      {_, reason} ->
        {:error, "Failed to fetch Ethereum balance: #{inspect(reason)}"}
    end
  end

  def balance_impl(address, "ethereumex") do
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

  def balance_impl(address, "ethereum-rpc") do
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

  def balance_impl(address, "blockscout") do
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
  alias ExWallet.Cycler

  def init_providers do
    sol_providers = ["mainnet-beta", "devnet"]

    case Cycler.start_link(:sol, sol_providers) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        Logger.debug("SOL Cycler already started")
        :ok

      {:error, reason} ->
        Logger.error("Failed to start SOL Cycler: #{inspect(reason)}")
        :abort
    end
  end

  @max_cycles 3

  defp next_provider, do: Cycler.next(:sol)

  def balance(address) do
    Logger.debug("Fetching SOL balance for address #{address}")

    ExWallet.TelemetryUtils.measure(
      [:balance_load, :sol],
      fn -> balance_try(address, @max_cycles) end
    )
  end

  # let's not fail for now
  defp balance_try(_address, t) when t <= 0 do
    Logger.debug("All SOL providers failed")
    {:ok, nil}
  end

  defp balance_try(address, t) do
    provider = next_provider()

    case balance_impl(address, provider) do
      {:ok, sol} ->
        :telemetry.execute(
          [:ex_wallet, :wallet, :balance_load, :sol, :success],
          %{count: 1},
          %{provider: provider}
        )

        {:ok, sol}

      {:error, reason} ->
        Logger.debug(
          "SOL provider #{provider} failed: #{inspect(reason)}. Trying next provider..."
        )

        :telemetry.execute(
          [:ex_wallet, :wallet, :balance_load, :sol, :error],
          %{count: 1},
          %{provider: provider}
        )

        sleep_rand_time = :rand.uniform(500)
        Process.sleep(sleep_rand_time)

        balance_try(address, t - 1)
    end
  end

  defp balance_impl(address, "mainnet-beta") do
    url = "https://api.mainnet-beta.solana.com"
    parse_sol(url, address)
  end

  defp balance_impl(address, "devnet") do
    url = "https://api.devnet.solana.com/"
    parse_sol(url, address)
  end

  defp parse_sol(url, address) do
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
        with {:ok, %{"result" => %{"value" => lamports}}} <- Jason.decode(body) do
          sol = lamports / 1.0e9
          {:ok, sol}
        else
          error ->
            {:error, "Failed to decode Solana response: #{inspect(error)}"}
        end

      {_, reason} ->
        {:error, reason}
    end
  end
end
