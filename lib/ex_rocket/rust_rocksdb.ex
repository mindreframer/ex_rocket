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
end
