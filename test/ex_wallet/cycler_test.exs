defmodule ExWallet.CyclerTest do
  use ExUnit.Case, async: true

  alias ExWallet.Cycler

  test "cycles through elements in order" do
    name = :test_cycler
    elements = [1, 2, 3]
    {:ok, _pid} = Cycler.start_link(name, elements)

    assert Cycler.next(name) == 1
    assert Cycler.next(name) == 2
    assert Cycler.next(name) == 3
    assert Cycler.next(name) == 1
    assert Cycler.next(name) == 2
  end

  test "returns nil if elements is empty" do
    name = :empty_cycler
    {:ok, _pid} = Cycler.start_link(name, [])
    assert Cycler.next(name) == nil
  end
end
