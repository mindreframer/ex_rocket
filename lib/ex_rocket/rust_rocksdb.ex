defmodule ExRocket.RustRocksDB do
  @moduledoc """
  Parallel ExRocket backend powered by the maintained `rust-rocksdb` crate.

  This module is intentionally independent from `ExRocket` so both native
  implementations can be loaded, tested, and benchmarked in the same runtime.
  """

  alias :erlang, as: Erlang

  @version Mix.Project.config()[:version]

  use RustlerPrecompiled,
    otp_app: :ex_rocket,
    crate: "rocker_maintained",
    base_url: "https://github.com/mindreframer/ex_rocket/releases/download/v#{@version}",
    nif_versions: ["2.16", "2.17"],
    targets: ~w(
      aarch64-apple-darwin
      x86_64-apple-darwin

      aarch64-unknown-linux-musl
      x86_64-unknown-linux-gnu
      x86_64-unknown-linux-musl

      x86_64-pc-windows-msvc
    ),
    force_build: String.downcase(System.get_env("FORCE_BUILD", "nope")) in ["1", "true", "yes"],
    version: @version

  def lxcode, do: Erlang.nif_error(:nif_not_loaded)
  def latest_sequence_number(_db_ref), do: Erlang.nif_error(:nif_not_loaded)
  def open(_path, _options \\ %{}), do: Erlang.nif_error(:nif_not_loaded)
  def open_for_read_only(_path, _options \\ %{}), do: Erlang.nif_error(:nif_not_loaded)
  def destroy(_path, _options \\ %{}), do: Erlang.nif_error(:nif_not_loaded)
  def repair(_path, _options \\ %{}), do: Erlang.nif_error(:nif_not_loaded)
  def get_db_path(_db_ref), do: Erlang.nif_error(:nif_not_loaded)
  def put(_db_ref, _key, _value), do: Erlang.nif_error(:nif_not_loaded)
  def get(_db_ref, _key), do: Erlang.nif_error(:nif_not_loaded)

  def get(db_ref, key, default) do
    case get(db_ref, key) do
      :undefined -> {:ok, default}
      result -> result
    end
  end

  def getb(db_ref, key) do
    case get(db_ref, key) do
      :undefined -> :undefined
      {:ok, value} -> {:ok, :erlang.binary_to_term(value)}
    end
  end

  def delete(_db_ref, _key), do: Erlang.nif_error(:nif_not_loaded)
end
