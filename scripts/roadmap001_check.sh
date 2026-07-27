#!/usr/bin/env bash
set -euo pipefail

export RUSTUP_TOOLCHAIN=1.91.0
export FORCE_BUILD=yes

mix format --check-formatted
cargo fmt --manifest-path native/rocker_maintained/Cargo.toml -- --check
mix compile --warnings-as-errors
mix test

if [[ "${RUN_BENCHMARK_SMOKE:-0}" == "1" ]]; then
  BENCH_TIME=1 BENCH_WARMUP=0 MIX_ENV=dev mix run benchmark/compare.exs
fi
