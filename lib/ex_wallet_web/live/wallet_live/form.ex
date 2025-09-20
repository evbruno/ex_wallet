defmodule ExWalletWeb.WalletLive.Form do
  use ExWalletWeb, :live_view

  alias ExWallet.Wallets
  alias ExWallet.Wallets.Wallet

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage wallet records in your database.</:subtitle>
      </.header>

      <.form for={@form} id="wallet-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />

        <.input
          field={@form[:mnemonic]}
          type="textarea"
          label="Mnemonic"
          phx-blur="validate_mnemonic"
        />
        <.button type="button" phx-click="generate_mnemonic" phx-value-long="false">
          Generate Mnemonic (12 words)
        </.button>
        <.button type="button" phx-click="generate_mnemonic" phx-value-long="true">
          Generate Mnemonic (24 words)
        </.button>

        <.input field={@form[:eth_address]} type="text" label="Ethereum address" readonly />
        <.input field={@form[:sol_address]} type="text" label="Solana address" readonly />
        <.input
          field={@form[:btc_legacy_address]}
          type="text"
          label="Bitcoin legacy address"
          readonly
        />
        <.input
          field={@form[:btc_nested_segwit_address]}
          type="text"
          label="Bitcoin nested segwit address"
          readonly
        />
        <.input
          field={@form[:btc_native_segwit_address]}
          type="text"
          label="Bitcoin native segwit address"
          readonly
        />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Wallet</.button>
          <.button navigate={return_path(@return_to, @wallet)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    wallet = Wallets.get_wallet!(id)

    socket
    |> assign(:page_title, "Edit Wallet")
    |> assign(:wallet, wallet)
    |> assign(:form, to_form(Wallets.change_wallet(wallet)))
  end

  defp apply_action(socket, :new, _params) do
    wallet = %Wallet{}

    socket
    |> assign(:page_title, "New Wallet")
    |> assign(:wallet, wallet)
    |> assign(:form, to_form(Wallets.change_wallet(wallet)))
  end

  @impl true
  def handle_event("validate", %{"wallet" => wallet_params}, socket) do
    changeset = Wallets.change_wallet(socket.assigns.wallet, wallet_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"wallet" => wallet_params}, socket) do
    save_wallet(socket, socket.assigns.live_action, wallet_params)
  end

  def handle_event("generate_mnemonic", %{"long" => long} = _params, socket) do
    mnemonic =
      case long do
        "true" -> Wallets.generate_mnemonic(true)
        _ -> Wallets.generate_mnemonic(false)
      end

    form = socket.assigns.form
    changes = form.source.changes
    params = Map.put(changes, :mnemonic, mnemonic) |> Wallets.load_addresses()
    changeset = Wallets.change_wallet(socket.assigns.wallet, params)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("validate_mnemonic", _params, socket) do
    form = socket.assigns.form
    changes = form.source.changes

    IO.inspect("Validating mnemonic with changes: #{inspect(changes)}")

    case Map.get(changes, :mnemonic) do
      nil ->
        {:noreply, socket}

      mnemonic ->
        IO.inspect("Mnemonic provided: #{mnemonic}")
        params = changes |> Wallets.load_addresses()
        changeset = Wallets.change_wallet(socket.assigns.wallet, params)
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_wallet(socket, :edit, wallet_params) do
    case Wallets.update_wallet(socket.assigns.wallet, wallet_params) do
      {:ok, wallet} ->
        {:noreply,
         socket
         |> put_flash(:info, "Wallet updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, wallet))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_wallet(socket, :new, wallet_params) do
    case Wallets.create_wallet(wallet_params) do
      {:ok, wallet} ->
        {:noreply,
         socket
         |> put_flash(:info, "Wallet created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, wallet))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _wallet), do: ~p"/wallets"
  defp return_path("show", wallet), do: ~p"/wallets/#{wallet}"
end
