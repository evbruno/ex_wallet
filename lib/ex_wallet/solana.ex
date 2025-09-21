defmodule ExWallet.Solana do
  @enforce_keys [:address]
  defstruct [:address, :balance]

  def new(address) do
    %__MODULE__{address: address, balance: Decimal.new(0)}
  end

  def root_key(mnemonic) do
    BlockKeys.from_mnemonic(mnemonic)
  end

  # def address_from_mnemonic_0(mnemonic, _account \\ "0") do
  #   root_key = root_key(mnemonic)
  #   path = "M/501'/0'/0'"
  #   xpub = CKD.derive(root_key, path, curve: :ed25519)
  #   xpub |> BlockKeys.Solana.Address.from_xpub()
  # end

  def address_from_mnemonic(mnemonic, _account \\ "0") do
    {:ok, w} = mnemonic_to_solana_address(mnemonic)
    w |> ExWallet.Solana.new()
  end

  ## vibe coded
  @hmac_key "ed25519 seed"
  @pbkdf2_iter 2048
  @pbkdf2_len 64

  @doc """
  Main convenience function.
  mnemonic: string of words (space separated)
  passphrase: optional (default empty string)
  path: list of integers for each path segment (unhardened numbers) — will be hardened automatically
        default: [44, 501, 0, 0]  => m/44'/501'/0'/0'
  returns: {:ok, base58_address} | {:error, reason}
  """
  def mnemonic_to_solana_address(mnemonic, passphrase \\ "", path \\ [44, 501, 0, 0])
      when is_binary(mnemonic) do
    seed = mnemonic_to_seed(mnemonic, passphrase)
    {k, c} = slip10_master_key(seed)

    {final_k, _final_c} =
      Enum.reduce(path, {k, c}, fn index, {parent_k, parent_c} ->
        derive_hardened_child(parent_k, parent_c, index)
      end)

    # final_k is 32 bytes: the Ed25519 seed used to create the keypair
    # ed25519.generate_key_pair/1 from :ed25519 accepts the 32-byte secret seed.
    {_secret, pub} = Ed25519.generate_key_pair(final_k)
    # pub is the 32-byte public key; Solana address is base58(pub)
    address = Base58.encode(pub)
    {:ok, address}
  rescue
    e -> {:error, e}
  end

  # BIP39 seed: PBKDF2-HMAC-SHA512 with salt = "mnemonic" <> passphrase, iter=2048, len=64
  defp mnemonic_to_seed(mnemonic, passphrase) do
    salt = "mnemonic" <> passphrase

    # :crypto.pbkdf2_hmac/5 is available in modern OTP. If your Erlang/OTP lacks it,
    # you'll need a small PBKDF2 implementation or add :pbkdf2_hex lib.
    :crypto.pbkdf2_hmac(:sha512, mnemonic, salt, @pbkdf2_iter, @pbkdf2_len)
  end

  # SLIP-0010 master key derivation for Ed25519:
  # I = HMAC-SHA512(key="ed25519 seed", data=seed)
  # master_secret = I[0:32], master_chain_code = I[32:64]
  defp slip10_master_key(seed) do
    i = :crypto.mac(:hmac, :sha512, @hmac_key, seed)
    <<k::binary-size(32), c::binary-size(32)>> = i
    {k, c}
  end

  # Hardened child derivation as SLIP-0010 (Ed25519):
  # data = 0x00 || parent_secret || index_be32 (with hardened bit set)
  # I = HMAC-SHA512(parent_chain_code, data)
  # child_secret = I[0:32], child_chain_code = I[32:64]
  defp derive_hardened_child(parent_k, parent_c, index) when is_integer(index) and index >= 0 do
    hardened_index = index + 0x8000_0000
    data = <<0>> <> parent_k <> <<hardened_index::32-big>>
    i = :crypto.mac(:hmac, :sha512, parent_c, data)
    <<k::binary-size(32), c::binary-size(32)>> = i
    {k, c}
  end
end
