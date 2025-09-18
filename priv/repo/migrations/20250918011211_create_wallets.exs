defmodule ExWallet.Repo.Migrations.CreateWallets do
  use Ecto.Migration

  def change do
    create table(:wallets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string
      add :mnemonic, :string
      add :eth_address, :string
      add :sol_address, :string
      add :btc_legacy_address, :string

      timestamps(type: :utc_datetime)
    end
  end
end
