#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export RUSTUP_TOOLCHAIN=1.91.0
export FORCE_BUILD=yes

mix format --check-formatted
cargo fmt --manifest-path native/rocker/Cargo.toml -- --check
mix clean
mix compile --warnings-as-errors
mix test
