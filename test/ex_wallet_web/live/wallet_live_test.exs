defmodule ExWalletWeb.WalletLiveTest do
  use ExWalletWeb.ConnCase

  import Phoenix.LiveViewTest
  import ExWallet.WalletsFixtures

  @create_attrs %{name: "some name", mnemonic: "some mnemonic", eth_address: "some eth_address", sol_address: "some sol_address", btc_legacy_address: "some btc_legacy_address"}
  @update_attrs %{name: "some updated name", mnemonic: "some updated mnemonic", eth_address: "some updated eth_address", sol_address: "some updated sol_address", btc_legacy_address: "some updated btc_legacy_address"}
  @invalid_attrs %{name: nil, mnemonic: nil, eth_address: nil, sol_address: nil, btc_legacy_address: nil}
  defp create_wallet(_) do
    wallet = wallet_fixture()

    %{wallet: wallet}
  end

  describe "Index" do
    setup [:create_wallet]

    test "lists all wallets", %{conn: conn, wallet: wallet} do
      {:ok, _index_live, html} = live(conn, ~p"/wallets")

      assert html =~ "Listing Wallets"
      assert html =~ wallet.name
    end

    test "saves new wallet", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/wallets")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Wallet")
               |> render_click()
               |> follow_redirect(conn, ~p"/wallets/new")

      assert render(form_live) =~ "New Wallet"

      assert form_live
             |> form("#wallet-form", wallet: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#wallet-form", wallet: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/wallets")

      html = render(index_live)
      assert html =~ "Wallet created successfully"
      assert html =~ "some name"
    end

    test "updates wallet in listing", %{conn: conn, wallet: wallet} do
      {:ok, index_live, _html} = live(conn, ~p"/wallets")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#wallets-#{wallet.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/wallets/#{wallet}/edit")

      assert render(form_live) =~ "Edit Wallet"

      assert form_live
             |> form("#wallet-form", wallet: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#wallet-form", wallet: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/wallets")

      html = render(index_live)
      assert html =~ "Wallet updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes wallet in listing", %{conn: conn, wallet: wallet} do
      {:ok, index_live, _html} = live(conn, ~p"/wallets")

      assert index_live |> element("#wallets-#{wallet.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#wallets-#{wallet.id}")
    end
  end

  describe "Show" do
    setup [:create_wallet]

    test "displays wallet", %{conn: conn, wallet: wallet} do
      {:ok, _show_live, html} = live(conn, ~p"/wallets/#{wallet}")

      assert html =~ "Show Wallet"
      assert html =~ wallet.name
    end

    test "updates wallet and returns to show", %{conn: conn, wallet: wallet} do
      {:ok, show_live, _html} = live(conn, ~p"/wallets/#{wallet}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/wallets/#{wallet}/edit?return_to=show")

      assert render(form_live) =~ "Edit Wallet"

      assert form_live
             |> form("#wallet-form", wallet: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#wallet-form", wallet: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/wallets/#{wallet}")

      html = render(show_live)
      assert html =~ "Wallet updated successfully"
      assert html =~ "some updated name"
    end
  end
end
