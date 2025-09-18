defmodule ExWallet.WalletsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ExWallet.Wallets` context.
  """

  @doc """
  Generate a wallet.
  """
  def wallet_fixture(attrs \\ %{}) do
    {:ok, wallet} =
      attrs
      |> Enum.into(%{
        btc_legacy_address: "some btc_legacy_address",
        eth_address: "some eth_address",
        mnemonic: "some mnemonic",
        name: "some name",
        sol_address: "some sol_address"
      })
      |> ExWallet.Wallets.create_wallet()

    wallet
  end
end
