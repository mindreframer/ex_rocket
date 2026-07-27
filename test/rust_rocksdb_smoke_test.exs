defmodule ExRocket.RustRocksDBSmokeTest do
  use ExUnit.Case, async: true

  test "primary facade and direct module use the maintained NIF" do
    assert {:ok, :vsn1} = ExRocket.lxcode()
    assert {:ok, :maintained, :vsn1} = ExRocket.RustRocksDB.lxcode()
  end
end
