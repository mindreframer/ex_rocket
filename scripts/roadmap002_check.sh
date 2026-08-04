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
cargo check --locked --manifest-path native/rocker/Cargo.toml

nif_path=$(find _build/test/lib/ex_rocket/native/rocker/release -maxdepth 1 -type f \
  \( -name 'librocker.so' -o -name 'librocker.dylib' -o -name 'rocker.dll' \) | head -n1)
test -n "$nif_path"

smoke_path=$nif_path
if [[ "$nif_path" == *.dylib ]]; then
  smoke_path="${TMPDIR:-/tmp}/librocker-roadmap002.so"
  cp "$nif_path" "$smoke_path"
fi
NIF_PATH="$smoke_path" elixir scripts/smoke_precompiled_nif.exs
[[ "$smoke_path" == "$nif_path" ]] || rm -f "$smoke_path"

package="ex_rocket-$(sed -n 's/^  @version "\(.*\)"/\1/p' mix.exs | head -n1).tar"
mix hex.build
contents=$(mktemp)
tar -xOf "$package" contents.tar.gz > "$contents"
tar -tzf "$contents" | grep -q '^OPTIONS.md$'
tar -tzf "$contents" | grep -q '^UPGRADING.md$'
rm -f "$contents" "$package"
