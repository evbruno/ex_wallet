defmodule ExWallet.Wallets.WalletBalance do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "wallet_balances" do
    field :eth_balance, :decimal
    field :sol_balance, :decimal
    field :btc_legacy_balance, :decimal
    field :btc_nested_segwit_balance, :decimal
    field :btc_native_segwit_balance, :decimal
    belongs_to :wallet, ExWallet.Wallets.Wallet, type: :binary_id

    timestamps()
  end

  def changeset(balance, attrs) do
    balance
    |> cast(attrs, [
      :eth_balance,
      :sol_balance,
      :btc_legacy_balance,
      :btc_nested_segwit_balance,
      :btc_native_segwit_balance,
      :wallet_id
    ])
    |> validate_required([:wallet_id])
  end

  defp to_value(nil), do: 0
  defp to_value(value) when is_number(value), do: value
  defp to_value(%Decimal{} = value), do: Decimal.to_float(value)

  def btc_balance(%__MODULE__{} = balance) do
    to_value(balance.btc_legacy_balance) +
      to_value(balance.btc_nested_segwit_balance) +
      to_value(balance.btc_native_segwit_balance)
  end

  def sol_balance(%__MODULE__{} = balance), do: to_value(balance.sol_balance)

  def eth_balance(%__MODULE__{} = balance), do: to_value(balance.eth_balance)
end
