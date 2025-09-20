defmodule ExWallet.Wallets do
  @moduledoc """
  The Wallets context.
  """

  import Ecto.Query, warn: false
  alias ExWallet.AddressService
  alias ExWallet.Repo

  alias ExWallet.Wallets.Wallet
  alias ExWallet.Wallets.WalletBalance
  alias ExWallet.BalanceService

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

  def generate_mnemonic(_long \\ false)

  def generate_mnemonic(false) do
    BlockKeys.Mnemonic.generate_phrase(:crypto.strong_rand_bytes(16))
  end

  def generate_mnemonic(_) do
    BlockKeys.Mnemonic.generate_phrase()
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

  defp ethereum_address(mnemonic) do
    AddressService.ethereum_address(mnemonic)
  end

  defp solana_address(mnemonic) do
    AddressService.solana_address(mnemonic)
  end

  defp bitcoin_address_legacy(mnemonic) do
    AddressService.bitcoin_address_legacy(mnemonic)
  end

  defp bitcoin_address_nested_segwit(mnemonic) do
    ExWallet.Bitcoin.NestedSegwit.address_from_mnemonic(mnemonic)
  end

  defp bitcoin_address_native_segwit(mnemonic) do
    ExWallet.Bitcoin.NativeSegwit.address_from_mnemonic(mnemonic)
  end

  def load_all_balances(%Wallet{} = wallet) do
    # IO.puts("Loading all balances for wallet ID: #{wallet.id}")

    load_all_balances_par(wallet)
    #  |> IO.inspect(label: "Balances fetched")
    # with {:ok, eth} <- BalanceService.ethereum_balance(wallet.eth_address),
    #      {:ok, sol} <- BalanceService.solana_balance(wallet.sol_address),
    #      {:ok, btc} <- BalanceService.bitcoin_balance(wallet.btc_legacy_address) do
    #   {:ok,
    #    %{
    #      eth_balance: eth,
    #      sol_balance: sol,
    #      btc_legacy_balance: btc,
    #      wallet_id: wallet.id
    #    }}
    # else
    #   {:error, reason} ->
    #     IO.puts("Failed to fetch balance: #{reason}")
    #     {:error, reason}
    # end
  end

  defdelegate eth_balance(a), to: BalanceService, as: :ethereum_balance
  defdelegate sol_balance(a), to: BalanceService, as: :solana_balance
  defdelegate btc_legacy_balance(a, type), to: BalanceService, as: :bitcoin_balance
  defdelegate btc_nested_segwit_balance(a, type), to: BalanceService, as: :bitcoin_balance
  defdelegate btc_native_segwit_balance(a, type), to: BalanceService, as: :bitcoin_balance

  defp load_async(what, value) do
    Task.async(fn ->
      with {:ok, res} <- apply(__MODULE__, what, value) do
        {what, res}
      else
        reason -> {:error, "#{what} balance error: #{inspect(reason)}"}
      end
    end)
  end

  def load_all_balances_par(%Wallet{} = wallet) do
    Task.await_many(
      [
        load_async(:eth_balance, [wallet.eth_address]),
        load_async(:sol_balance, [wallet.sol_address]),
        load_async(:btc_legacy_balance, [wallet.btc_legacy_address, :legacy]),
        load_async(:btc_nested_segwit_balance, [wallet.btc_nested_segwit_address, :nested_segwit]),
        load_async(:btc_native_segwit_balance, [wallet.btc_native_segwit_address, :native_segwit])
      ],
      20_000
    )
    |> Enum.into(%{wallet_id: wallet.id})
    |> then(fn r -> {:ok, r} end)

    # |> IO.inspect(label: "load_all_balances_par result")
  end
end
