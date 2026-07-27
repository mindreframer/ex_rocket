#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ex_rocket_compat.XXXXXX")"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

cd "$ROOT_DIR"
export RUSTUP_TOOLCHAIN=1.91.0
export FORCE_BUILD=yes

mix compile

run_script() {
  local backend="$1"
  local path="$2"
  local script="$3"
  EX_ROCKET_BACKEND="$backend" \
  EX_ROCKET_COMPAT_PATH="$path" \
    mix run --no-compile "$script"
}

legacy_path="$WORK_DIR/legacy_written"
maintained_path="$WORK_DIR/maintained_written"

echo "== Legacy write -> maintained read =="
run_script legacy "$legacy_path" scripts/compatibility/write.exs
run_script maintained "$legacy_path" scripts/compatibility/read.exs

echo "== Maintained write -> legacy read =="
run_script maintained "$maintained_path" scripts/compatibility/write.exs
run_script legacy "$maintained_path" scripts/compatibility/read.exs

echo "Bidirectional RocksDB compatibility checks passed."
