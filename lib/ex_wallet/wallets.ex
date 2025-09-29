defmodule ExWallet.Wallets do
  @moduledoc """
  The Wallets context.
  """

  require Logger

  import Ecto.Query, warn: false

  alias ExWallet.Repo

  alias ExWallet.Wallets.Wallet
  alias ExWallet.Wallets.WalletBalance
  alias ExWallet.BalanceService

  alias BlockKeys.Mnemonic, as: BKM
  alias BitcoinLib.Key.HD.SeedPhrase, as: BLIB

  @doc """
  Returns the list of wallets.

  ## Examples

      iex> list_wallets()
      [%Wallet{}, ...]

  """
  def list_wallets(safe \\ false)

  def list_wallets(true) do
    Repo.all(Wallet)
  end

  def list_wallets(_) do
    Repo.all(Wallet)
    |> Enum.map(fn wallet -> %{wallet | mnemonic: "***"} end)
  end

  def list_wallets_paginated(page \\ 1, per_page \\ 20) do
    wallets =
      Repo.all(from w in Wallet, limit: ^per_page, offset: ^((page - 1) * per_page))

    total = Repo.aggregate(Wallet, :count, :id)

    {wallets, total}
  end

  @doc """
  Gets a single wallet.

  Raises `Ecto.NoResultsError` if the Wallet does not exist.

  ## Examples

      iex> get_wallet!(123)
      %Wallet{}

      iex> get_wallet!(456)
      ** (Ecto.NoResultsError)

  """
  def get_wallet!(id), do: Repo.get!(Wallet, id) |> Repo.preload(:balance)

  def get_balance(id), do: Repo.get!(WalletBalance, id)

  def find_by_mnemonic(mnemonic) do
    Repo.get_by(Wallet, mnemonic: mnemonic)
    |> Repo.preload(:balance)
  end

  def find_by_start_mnemonic(mnemonic_start) do
    Repo.all(from w in Wallet, where: like(w.mnemonic, ^"#{mnemonic_start}%"))
    |> Repo.preload(:balance)
  end

  def find_by_name(name) do
    Repo.all(from w in Wallet, where: w.name == ^name)
    |> Repo.preload(:balance)
  end

  @doc """
  Creates a wallet.

  ## Examples

      iex> create_wallet(%{field: value})
      {:ok, %Wallet{}}

      iex> create_wallet(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_wallet(attrs) do
    %Wallet{}
    |> Wallet.changeset(attrs)
    |> Repo.insert()
  end

  def create_balance(%Wallet{} = wallet, attrs) do
    %WalletBalance{wallet_id: wallet.id}
    |> WalletBalance.changeset(attrs)
    |> Repo.insert()
  end

  def create_or_update_balance(%Wallet{} = wallet, attrs) do
    case Repo.get_by(WalletBalance, wallet_id: wallet.id) do
      nil ->
        create_balance(wallet, attrs)

      %WalletBalance{} = balance ->
        balance
        |> WalletBalance.changeset(attrs)
        |> Repo.update()
    end
  end

  @doc """
  Updates a wallet.

  ## Examples

      iex> update_wallet(wallet, %{field: new_value})
      {:ok, %Wallet{}}

      iex> update_wallet(wallet, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_wallet(%Wallet{} = wallet, attrs) do
    wallet
    |> Wallet.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a wallet.

  ## Examples

      iex> delete_wallet(wallet)
      {:ok, %Wallet{}}

      iex> delete_wallet(wallet)
      {:error, %Ecto.Changeset{}}

  """
  def delete_wallet(%Wallet{} = wallet) do
    Repo.delete(wallet)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking wallet changes.

  ## Examples

      iex> change_wallet(wallet)
      %Ecto.Changeset{data: %Wallet{}}

  """
  def change_wallet(%Wallet{} = wallet, attrs \\ %{}) do
    Wallet.changeset(wallet, attrs)
  end

  def generate_mnemonic(_words \\ 12)

  def generate_mnemonic(words) when words in [12, 24] do
    method = random_impl()
    apply(__MODULE__, method, [words])
  end

  def blockeys_impl(w) do
    rand_bytes(w) |> BKM.generate_phrase()
  end

  def bitcoinlib_impl(w) when w in [12, 24] do
    rand_bytes(w)
    |> :binary.decode_unsigned()
    |> BLIB.wordlist_from_entropy()
  end

  defp rand_bytes(size) when size in [12, 24] do
    case size do
      12 -> :crypto.strong_rand_bytes(16)
      24 -> :crypto.strong_rand_bytes(32)
    end
  end

  def random_impl() do
    case :rand.uniform(1024) |> rem(2) do
      0 -> :blockeys_impl
      1 -> :bitcoinlib_impl
    end
  end

  def load_addresses(%Wallet{mnemonic: mnemonic} = wallet) do
    %{
      wallet
      | eth_address: ethereum_address(mnemonic),
        sol_address: solana_address(mnemonic),
        btc_legacy_address: bitcoin_address_legacy(mnemonic),
        btc_nested_segwit_address: bitcoin_address_nested_segwit(mnemonic),
        btc_native_segwit_address: bitcoin_address_native_segwit(mnemonic)
    }
  end

  def load_addresses(%{mnemonic: mnemonic} = wallet) do
    wallet
    |> Map.put(:eth_address, ethereum_address(mnemonic))
    |> Map.put(:sol_address, solana_address(mnemonic))
    |> Map.put(:btc_legacy_address, bitcoin_address_legacy(mnemonic))
    |> Map.put(:btc_nested_segwit_address, bitcoin_address_nested_segwit(mnemonic))
    |> Map.put(:btc_native_segwit_address, bitcoin_address_native_segwit(mnemonic))
  end

  def ethereum_address(mnemonic) do
    # AddressService.ethereum_address(mnemonic)
    ExWallet.Ethereum.addresss_from_mnemonic(mnemonic).address
  end

  def solana_address(mnemonic) do
    # AddressService.solana_address(mnemonic)
    ExWallet.Solana.address_from_mnemonic(mnemonic).address
  end

  def bitcoin_address_legacy(mnemonic) do
    # AddressService.bitcoin_address_legacy(mnemonic)
    ExWallet.Bitcoin.Legacy.address_from_mnemonic(mnemonic).address
  end

  def bitcoin_address_nested_segwit(mnemonic) do
    ExWallet.Bitcoin.NestedSegwit.address_from_mnemonic(mnemonic).address
  end

  def bitcoin_address_native_segwit(mnemonic) do
    ExWallet.Bitcoin.NativeSegwit.address_from_mnemonic(mnemonic).address
  end

  # not fail the whole update if one balance fails
  defp load_sync(what, value) do
    with {:ok, res} <- apply(__MODULE__, what, [value]) do
      {what, res}
    else
      reason ->
        Logger.debug({"#{what} balance error: #{inspect(reason)}"})
        {what, nil}
    end
  end

  def load_all_balances(%Wallet{} = wallet) do
    ExWallet.TelemetryUtils.measure(
      [:balance_load, :all],
      fn -> load_all_balances_impl(wallet) end
    )
  end

  defp load_all_balances_impl(wallet) do
    [
      load_sync(:eth_balance, wallet.eth_address),
      load_sync(:sol_balance, wallet.sol_address),
      load_sync(:btc_legacy_balance, wallet.btc_legacy_address),
      load_sync(:btc_nested_segwit_balance, wallet.btc_nested_segwit_address),
      load_sync(:btc_native_segwit_balance, wallet.btc_native_segwit_address)
    ]
    |> Enum.into(%{wallet_id: wallet.id})
    |> then(fn r -> {:ok, r} end)
  end

  defdelegate eth_balance(a), to: BalanceService, as: :ethereum_balance
  defdelegate sol_balance(a), to: BalanceService, as: :solana_balance
  defdelegate btc_legacy_balance(a), to: BalanceService, as: :bitcoin_balance
  defdelegate btc_nested_segwit_balance(a), to: BalanceService, as: :bitcoin_balance
  defdelegate btc_native_segwit_balance(a), to: BalanceService, as: :bitcoin_balance

  def balance_to_usd(%WalletBalance{} = balance) do
    eth =
      case ExWallet.PriceService.ethereum_usd() do
        {:ok, p} ->
          p * (balance |> WalletBalance.eth_balance())

        err ->
          Logger.error("Error fetching ETH price: #{inspect(err)}")
          0
      end

    btc =
      case ExWallet.PriceService.bitcoin_usd() do
        {:ok, p} ->
          p * (balance |> WalletBalance.btc_balance())

        err ->
          Logger.error("Error fetching BTC price: #{inspect(err)}")
          0
      end

    sol =
      case ExWallet.PriceService.solana_usd() do
        {:ok, p} ->
          p * (balance |> WalletBalance.sol_balance())

        err ->
          Logger.error("Error fetching SOL price: #{inspect(err)}")
          0
      end

    %{eth: eth, btc: btc, sol: sol, total: eth + btc + sol}
  end

  # defp load_async(what, value) do
  #   Task.async(fn ->
  #     with {:ok, res} <- apply(__MODULE__, what, [value]) do
  #       {what, res}
  #     else
  #       reason -> {:error, "#{what} balance error: #{inspect(reason)}"}
  #     end
  #   end)
  # end

  # 429 => Rate limited
  # cant use it for now
  #   defp load_all_balances_par(%Wallet{} = wallet) do
  #     Logger.info("Loading all balances for wallet #{wallet.id}")

  #     Task.await_many(
  #       [
  #         load_async(:eth_balance, wallet.eth_address),
  #         load_async(:sol_balance, wallet.sol_address),
  #         load_async(:btc_legacy_balance, wallet.btc_legacy_address),
  #         load_async(:btc_nested_segwit_balance, wallet.btc_nested_segwit_address),
  #         load_async(:btc_native_segwit_balance, wallet.btc_native_segwit_address)
  #       ],
  #       20_000
  #     )
  #     |> Enum.into(%{wallet_id: wallet.id})
  #     |> then(fn r -> {:ok, r} end)
  #   end
  # end
end
