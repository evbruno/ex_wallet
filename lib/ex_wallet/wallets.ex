defmodule ExWallet.Wallets do
  @moduledoc """
  The Wallets context.
  """

  import Ecto.Query, warn: false
  alias ExWallet.AddressService
  alias ExWallet.Repo

  alias ExWallet.Wallets.Wallet
  alias ExWallet.Wallets.WalletBalance

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

  def generate_mnemonic() do
    BlockKeys.Mnemonic.generate_phrase()
  end

  def load_addresses(%Wallet{mnemonic: mnemonic} = wallet) do
    %{
      wallet
      | eth_address: ethereum_address(mnemonic),
        sol_address: solana_address(mnemonic),
        btc_legacy_address: bitcoin_address_legacy(mnemonic)
    }
  end

  def load_addresses(%{mnemonic: mnemonic} = wallet) do
    wallet
    |> Map.put(:eth_address, ethereum_address(mnemonic))
    |> Map.put(:sol_address, solana_address(mnemonic))
    |> Map.put(:btc_legacy_address, bitcoin_address_legacy(mnemonic))
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
end
