defmodule ExWallet.Repo.Migrations.AddSeedIndexUniq do
  use Ecto.Migration

  def change do
    drop_if_exists index(:wallets, [:mnemonic])
    create unique_index(:wallets, [:mnemonic])
  end
end
