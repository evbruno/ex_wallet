defmodule ExWallet.Ethereum do
  alias BlockKeys.CKD
  alias BlockKeys.Ethereum.Address

  def root_key(mnemonic) do
    BlockKeys.from_mnemonic(mnemonic)
  end

  def addresss_from_mnemonic(mnemonic, account \\ "0") do
    root_key(mnemonic)
    |> CKD.derive("M/44'/60'/0'/0/#{account}")
    |> Address.from_xpub()
  end
end
