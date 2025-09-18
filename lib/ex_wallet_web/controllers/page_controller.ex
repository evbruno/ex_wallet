defmodule ExWalletWeb.PageController do
  use ExWalletWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
