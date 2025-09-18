defmodule ExWallet.Repo.Migrations.CreateWalletBalance do
  use Ecto.Migration

  def change do
    create table(:wallet_balances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :eth_balance, :decimal
      add :sol_balance, :decimal
      add :btc_legacy_balance, :decimal
      add :wallet_id, references(:wallets, type: :binary_id, on_delete: :delete_all)

      timestamps()
    end

    create index(:wallet_balances, [:wallet_id])
  end
end
