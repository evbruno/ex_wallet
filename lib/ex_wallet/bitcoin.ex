defmodule ExWallet.Bitcoin do
  @enforce_keys [:address, :type]
  defstruct [:address, :balance, :type]

  def new(address, type) when type in [:legacy, :nested_segwit, :native_segwit] do
    %__MODULE__{address: address, type: type, balance: Decimal.new(0)}
  end
end

defmodule ExWallet.Bitcoin.Utils do
  alias BitcoinLib.Key.HD.DerivationPath
  alias BitcoinLib.Key.{PrivateKey, PublicKey}

  @dialyzer {:nowarn_function, derive_path!: 2}
  defp derive_path!(purpose, account) do
    case DerivationPath.parse("m/#{purpose}'/0'/#{account}'/0/0") do
      {:ok, path} -> path
      reason -> raise "Invalid derivation path: #{inspect(reason)}"
    end
  end

  @dialyzer {:nowarn_function, address_from_mnemonic!: 4}
  def address_from_mnemonic(mnemonic, account, purpose, address_module) do
    path = derive_path!(purpose, account)

    mnemonic
    |> PrivateKey.from_seed_phrase()
    |> PrivateKey.from_derivation_path!(path)
    |> PublicKey.from_private_key()
    |> address_module.from_public_key()
  end
end

defmodule ExWallet.Bitcoin.Legacy do
  alias ExWallet.Bitcoin.Utils

  @purpose "44"

  @dialyzer :no_return
  def address_from_mnemonic(mnemonic, account \\ "0") do
    Utils.address_from_mnemonic(
      mnemonic,
      account,
      @purpose,
      BitcoinLib.Address.P2PKH
    )
  end
end

defmodule ExWallet.Bitcoin.NativeSegwit do
  alias ExWallet.Bitcoin.Utils

  @purpose "84"

  @dialyzer :no_return
  def address_from_mnemonic(mnemonic, account \\ "0") do
    Utils.address_from_mnemonic(
      mnemonic,
      account,
      @purpose,
      BitcoinLib.Address.Bech32
    )
  end
end

defmodule ExWallet.Bitcoin.NestedSegwit do
  alias ExWallet.Bitcoin.Utils

  @purpose "49"

  @dialyzer :no_return
  def address_from_mnemonic(mnemonic, account \\ "0") do
    Utils.address_from_mnemonic(
      mnemonic,
      account,
      @purpose,
      BitcoinLib.Address.P2SH
    )
  end
end
