defmodule ExWalletWeb.WalletLive.Index do
  use ExWalletWeb, :live_view

  alias ExWallet.Wallets

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Wallets
        <:actions>
          <.button variant="primary" navigate={~p"/wallets/new"}>
            <.icon name="hero-plus" /> New Wallet
          </.button>
        </:actions>
      </.header>

      <.table
        id="wallets"
        rows={@streams.wallets}
        row_click={fn {_id, wallet} -> JS.navigate(~p"/wallets/#{wallet}") end}
      >
        <:col :let={{_id, wallet}} label="Name">{wallet.name}</:col>
        <:col :let={{_id, wallet}} label="Mnemonic">{wallet.mnemonic}</:col>
        <%!-- <:col :let={{_id, wallet}} label="Eth address">{wallet.eth_address}</:col> --%>
        <:col :let={{_id, wallet}} label="Eth address">
          <span title={wallet.eth_address}>
            {String.slice(wallet.eth_address, 0, 4)}...{String.slice(wallet.eth_address, -4, 4)}
          </span>
        </:col>
        <:col :let={{_id, wallet}} label="Sol address">
          <span title={wallet.sol_address}>
            {String.slice(wallet.sol_address, 0, 4)}...{String.slice(wallet.sol_address, -4, 4)}
          </span>
        </:col>
        <:col :let={{_id, wallet}} label="Btc legacy address">
          <span title={wallet.btc_legacy_address}>
            {String.slice(wallet.btc_legacy_address, 0, 4)}...{String.slice(
              wallet.btc_legacy_address,
              -4,
              4
            )}
          </span>
        </:col>
        <:action :let={{_id, wallet}}>
          <div class="sr-only">
            <.link navigate={~p"/wallets/#{wallet}"}>Show</.link>
          </div>
          <.link navigate={~p"/wallets/#{wallet}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, wallet}}>
          <.link
            phx-click={JS.push("delete", value: %{id: wallet.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Wallets")
     |> stream(:wallets, list_wallets())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    wallet = Wallets.get_wallet!(id)
    {:ok, _} = Wallets.delete_wallet(wallet)

    {:noreply, stream_delete(socket, :wallets, wallet)}
  end

  defp list_wallets() do
    Wallets.list_wallets()
  end
end
