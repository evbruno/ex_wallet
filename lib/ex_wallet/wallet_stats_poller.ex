defmodule ExWallet.WalletStatsPoller do
  use GenServer
  require Logger

  def start_link(_), do: GenServer.start_link(__MODULE__, %{})

  @impl true
  def init(state) do
    schedule_count()

    Logger.debug("WalletStatsPoller init: #{inspect(state)}")

    {:ok, state}
  end

  @impl true
  def handle_info(:count, state) do
    count = ExWallet.Repo.aggregate(ExWallet.Wallets.Wallet, :count, :id)
    :telemetry.execute([:ex_wallet, :wallet, :stats], %{count: count}, %{})
    schedule_count()

    Logger.debug("Wallet count: #{count}")

    {:noreply, state}
  end

  defp schedule_count, do: Process.send_after(self(), :count, 10_000)
end
