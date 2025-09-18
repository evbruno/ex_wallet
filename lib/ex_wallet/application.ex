defmodule ExWallet.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExWalletWeb.Telemetry,
      ExWallet.Repo,
      {Ecto.Migrator,
       repos: Application.fetch_env!(:ex_wallet, :ecto_repos), skip: skip_migrations?()},
      {DNSCluster, query: Application.get_env(:ex_wallet, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ExWallet.PubSub},
      {Finch, name: ExWallet.Finch},
      ExWallet.SimpleCache,
      # Start a worker by calling: ExWallet.Worker.start_link(arg)
      # {ExWallet.Worker, arg},
      # Start to serve requests, typically the last entry
      ExWalletWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExWallet.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExWalletWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
