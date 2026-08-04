#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

export RUSTUP_TOOLCHAIN=1.91.0
export FORCE_BUILD=yes
export MIX_ENV=test

qa_stage() {
  printf '\n[qa/%s] %s\n' "$1" "$2"
}

run_quiet() {
  local output
  local status

  if output=$("$@" 2>&1); then
    return 0
  else
    status=$?
    printf '%s\n' "$output" >&2
    return "$status"
  fi
}

qa_stage versions "validate package/native version parity"
scripts/project_version.sh

qa_stage elixir "dependencies, format, compile, and static analysis"
run_quiet mix deps.get --check-locked
mix deps.unlock --check-unused
mix format --check-formatted
mix compile --warnings-as-errors
mix credo --strict

qa_stage elixir "ExUnit"
mix test --no-compile

qa_stage rust "format"
cargo fmt --manifest-path native/rocker/Cargo.toml --all -- --check

qa_stage rust "check"
cargo check --manifest-path native/rocker/Cargo.toml --locked --all-targets

qa_stage nif "functional raw-library smoke"
nif_path=$(find _build/test/lib/ex_rocket/native/rocker/release -maxdepth 1 -type f \
  \( -name 'librocker.so' -o -name 'librocker.dylib' -o -name 'rocker.dll' \) -print -quit)
test -n "$nif_path"

smoke_path=$nif_path
if [[ "$nif_path" == *.dylib ]]; then
  smoke_path="${TMPDIR:-/tmp}/librocker-ex-rocket-qa.so"
  cp "$nif_path" "$smoke_path"
fi
NIF_PATH="$smoke_path" elixir scripts/smoke_precompiled_nif.exs
[[ "$smoke_path" == "$nif_path" ]] || rm -f "$smoke_path"

qa_stage package "build and inspect unpacked Hex package"
rm -rf .ci/package
mix hex.build --unpack --output .ci/package
test -f .ci/package/checksum-Elixir.ExRocket.exs
test -f .ci/package/OPTIONS.md
test -f .ci/package/UPGRADING.md
rm -rf .ci/package

qa_stage ok "all checks passed"
