defmodule ExWallet.Wallets.Wallet do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "wallets" do
    field :name, :string
    field :mnemonic, :string
    field :eth_address, :string
    field :sol_address, :string
    field :btc_legacy_address, :string
    field :btc_nested_segwit_address, :string
    field :btc_native_segwit_address, :string

    has_one :balance, ExWallet.Wallets.WalletBalance

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(wallet, attrs) do
    wallet
    |> cast(attrs, [
      :name,
      :mnemonic,
      :eth_address,
      :sol_address,
      :btc_legacy_address,
      :btc_nested_segwit_address,
      :btc_native_segwit_address
    ])
    |> validate_required([
      :name,
      :mnemonic,
      :eth_address,
      :sol_address,
      :btc_legacy_address,
      :btc_nested_segwit_address,
      :btc_native_segwit_address
    ])
  end
end
