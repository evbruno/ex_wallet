defmodule ExWalletWeb.Router do
  use ExWalletWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ExWalletWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ExWalletWeb do
    pipe_through :browser

    get "/", PageController, :home

    live "/wallets", WalletLive.Index, :index
    live "/wallets/new", WalletLive.Form, :new
    live "/wallets/:id", WalletLive.Show, :show
    live "/wallets/:id/edit", WalletLive.Form, :edit
  end

  scope "/live", ExWalletWeb, log: false do
    pipe_through :api

    get "/", PageController, :check
    get "/check", PageController, :check
  end

  # Other scopes may use custom stacks.
  # scope "/api", ExWalletWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:ex_wallet, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ExWalletWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
