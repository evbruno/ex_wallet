defmodule ExWalletWeb.WalletLive.Index do
  use ExWalletWeb, :live_view

  alias ExWallet.Wallets
  alias ExWallet.Wallets.Wallet

  @per_page 50

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

      <p class="text-sm text-gray-500 mb-4">
        Total wallets: {@total} (page {@curr_page} of {@total_pages})
      </p>

      <footer>
        <.button :if={@curr_page > 1} phx-click="paginate" phx-value-delta="-1">
          Previous
        </.button>

        <.button :if={@curr_page < @total_pages} phx-click="paginate" phx-value-delta="+1">
          Next
        </.button>
      </footer>

      <.table
        id="wallets"
        rows={@streams.wallets}
        row_click={fn {_id, wallet} -> JS.navigate(~p"/wallets/#{wallet}") end}
      >
        <:col :let={{_id, wallet}} label="Name">{wallet.name}</:col>
        <:col :let={{_id, wallet}} label="Mnemonic">
          <span title={count_words(wallet)}>
            {render_text(wallet.mnemonic, 8)}
          </span>
        </:col>
        <%!-- <:col :let={{_id, wallet}} label="Eth address">{wallet.eth_address}</:col> --%>
        <:col :let={{_id, wallet}} label="Eth address">
          <span title={wallet.eth_address}>
            {render_text(wallet.eth_address)}
          </span>
        </:col>
        <:col :let={{_id, wallet}} label="Sol address">
          <span title={wallet.sol_address}>
            {render_text(wallet.sol_address)}
          </span>
        </:col>
        <:col :let={{_id, wallet}} label="Btc legacy">
          <span title={wallet.btc_legacy_address}>
            {render_text(wallet.btc_legacy_address)}
          </span>
        </:col>
        <:col :let={{_id, wallet}} label="Btc Native Segwit">
          <span title={wallet.btc_native_segwit_address}>
            {render_text(wallet.btc_native_segwit_address)}
          </span>
        </:col>
        <:col :let={{_id, wallet}} label="Btc Nested Segwit">
          <span title={wallet.btc_nested_segwit_address}>
            {render_text(wallet.btc_nested_segwit_address)}
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

  def render_text(""), do: "N/A"
  def render_text(nil), do: "N/A"
  def render_text(str) when byte_size(str) <= 10, do: str

  def render_text(str, delta \\ 4) do
    String.slice(str, 0, delta) <> "..." <> String.slice(str, -delta, delta)
  end

  def count_words(%Wallet{} = wallet) do
    x =
      wallet.mnemonic
      |> String.split()
      |> length()

    "#{x} words"
  end

  @impl true
  def mount(_params, _session, socket) do
    {ws, t, total_pages} = list_wallets_p()

    {:ok,
     socket
     |> assign(:page_title, "Listing Wallets")
     |> assign(:total, t)
     |> assign(:curr_page, 1)
     |> assign(:total_pages, total_pages)
     |> stream(:wallets, ws)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    wallet = Wallets.get_wallet!(id)
    {:ok, _} = Wallets.delete_wallet(wallet)

    {:noreply, stream_delete(socket, :wallets, wallet)}
  end

  # def handle_event("next_page", _params, socket) do
  #   next_page = socket.assigns.curr_page + 1
  #   {ws, t} = list_wallets_p(next_page)
  #   total_pages = t / @per_page

  #   socket =
  #     socket
  #     |> assign(:curr_page, next_page)
  #     |> assign(:total, t)
  #     |> assign(:total_pages, total_pages)
  #     |> stream(:wallets, ws, reset: true)

  #   {:noreply, socket}
  # end

  def handle_event("paginate", %{"delta" => delta} = _params, socket) do
    next_page = socket.assigns.curr_page + String.to_integer(delta)
    {ws, t, total_pages} = list_wallets_p(next_page)

    socket =
      socket
      |> assign(:curr_page, next_page)
      |> assign(:total, t)
      |> assign(:total_pages, total_pages)
      |> stream(:wallets, ws, reset: true)

    {:noreply, socket}
  end

  # defp list_wallets() do
  #   Wallets.list_wallets()
  # end

  defp list_wallets_p(page \\ 0) do
    {ws, total} = Wallets.list_wallets_paginated(page, @per_page)
    total_pages = :math.ceil(total / @per_page) |> trunc()
    {ws, total, total_pages}
  end
end
