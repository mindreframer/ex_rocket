defmodule ExRocket.RustRocksDBSmokeTest do
  use ExUnit.Case, async: true

  test "legacy and maintained NIFs load independently" do
    assert {:ok, :vsn1} = ExRocket.lxcode()
    assert {:ok, :maintained, :vsn1} = ExRocket.RustRocksDB.lxcode()
  end
end
