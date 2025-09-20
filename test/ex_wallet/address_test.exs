defmodule ExWallet.AddressTest do
  use ExUnit.Case, async: true

  @mnemonic "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

  test "derive Ethereum address from mnemonic" do
    address = ExWallet.Ethereum.addresss_from_mnemonic(@mnemonic)
    # expected for this mnemonic/account 0
    assert address == "0x9858EfFD232B4033E47d90003D41EC34EcaEda94"
  end

  test "derive Solana address from mnemonic" do
    address = ExWallet.Solana.address_from_mnemonic(@mnemonic)
    # replace with actual expected
    assert address == "HAgk14JpMQLgt6rVgv7cBQFJWFto5Dqxi472uT3DKpqk"
  end

  test "derive Bitcoin legacy address from mnemonic" do
    address = ExWallet.Bitcoin.Legacy.address_from_mnemonic(@mnemonic)
    # expected for this mnemonic/account 0
    assert address == "1LqBGSKuX5yYUonjxT5qGfpUsXKYYWeabA"
  end

  test "derive Bitcoin nested segwit address from mnemonic" do
    address = ExWallet.Bitcoin.NestedSegwit.address_from_mnemonic(@mnemonic)
    # replace with actual expected
    assert address == "37VucYSaXLCAsxYyAPfbSi9eh4iEcbShgf"
  end

  test "derive Bitcoin native segwit address from mnemonic" do
    address = ExWallet.Bitcoin.NativeSegwit.address_from_mnemonic(@mnemonic)
    # expected for this mnemonic/account 0
    assert address == "bc1qcr8te4kr609gcawutmrza0j4xv80jy8z306fyu"
  end
end
