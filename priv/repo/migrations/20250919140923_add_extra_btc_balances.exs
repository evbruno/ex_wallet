defmodule ExWallet.Repo.Migrations.AddExtraBtcBalances do
  use Ecto.Migration

  def change do
    alter table(:wallets) do
      add :btc_nested_segwit_address, :string
      add :btc_native_segwit_address, :string
    end

    alter table(:wallet_balances) do
      add :btc_nested_segwit_balance, :decimal
      add :btc_native_segwit_balance, :decimal
    end

    create index(:wallets, [:mnemonic])
  end
end
