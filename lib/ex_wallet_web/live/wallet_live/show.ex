defmodule ExWalletWeb.WalletLive.Show do
  use ExWalletWeb, :live_view

  alias ExWallet.Wallets
  alias ExWallet.BalanceService

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Wallet {@wallet.id}
        <:subtitle>This is a wallet record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/wallets"}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button variant="primary" navigate={~p"/wallets/#{@wallet}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit wallet
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@wallet.name}</:item>
        <:item title="Mnemonic">{@wallet.mnemonic}</:item>
        <:item title="Eth address">{@wallet.eth_address}</:item>
        <:item title="Sol address">{@wallet.sol_address}</:item>
        <:item title="Btc legacy address">{@wallet.btc_legacy_address}</:item>
      </.list>
      <.list :if={@wallet.balance}>
        <:item title="Eth balance">{@wallet.balance.eth_balance}</:item>
        <:item title="Sol balance">{@wallet.balance.sol_balance}</:item>
        <:item title="Btc legacy balance">{@wallet.balance.btc_legacy_balance}</:item>
        <:item title="Inserted at">
          {Calendar.strftime(
            DateTime.from_naive!(@wallet.inserted_at, "Etc/UTC"),
            "%Y-%m-%d %H:%M:%S %Z"
          )}
        </:item>
      </.list>
      <%= if is_nil(@wallet.balance) do %>
        <div class="alert alert-warning">
          <small class="badge badge-warning badge-sm ml-3">
            No balance found for this wallet.
          </small>
        </div>
      <% end %>

      <.button phx-click="reload_balance" variant="primary">
        Reload Balance
      </.button>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("reload_balance", _params, socket) do
    IO.inspect("Reloading balance for wallet: #{inspect(socket.assigns.wallet)}")

    wallet = Wallets.get_wallet!(socket.assigns.wallet.id)

    with {:ok, eth} <-
           BalanceService.ethereum_balance(wallet.eth_address),
         {:ok, sol} <- BalanceService.solana_balance(wallet.sol_address),
         {:ok, btc} <- BalanceService.bitcoin_balance(wallet.btc_legacy_address) do
      balance_params = %{
        eth_balance: eth,
        sol_balance: sol,
        btc_legacy_balance: btc,
        wallet_id: socket.assigns.wallet.id
      }

      case Wallets.create_or_update_balance(wallet, balance_params) do
        {:ok, balance} ->
          IO.puts("Balance updated: #{inspect(balance)}")

          {:noreply,
           socket
           |> assign(:wallet, Wallets.get_wallet!(socket.assigns.wallet.id))
           |> put_flash(:info, "Balance reloaded successfully.")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to update balance.")}
      end
    else
      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to fetch balance: #{reason}")}
    end
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Wallet")
     |> assign(:wallet, Wallets.get_wallet!(id))}
  end
end
