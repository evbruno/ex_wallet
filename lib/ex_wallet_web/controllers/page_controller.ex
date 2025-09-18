defmodule ExWalletWeb.PageController do
  use ExWalletWeb, :controller

  def home(conn, _params) do
    {:ok, btc} = ExWallet.PriceService.bitcoin_usd()
    {:ok, eth} = ExWallet.PriceService.ethereum_usd()
    {:ok, sol} = ExWallet.PriceService.solana_usd()

    conn
    |> assign(:btc_price, btc)
    |> assign(:eth_price, eth)
    |> assign(:sol_price, sol)
    |> render(:home)
  end
end
