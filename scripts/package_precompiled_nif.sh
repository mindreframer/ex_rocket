#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <project-version> <nif-version> <target>" >&2
  exit 64
fi

project_version=$1
nif_version=$2
target=$3
project_name=rocker
project_dir=native/rocker

lib_prefix=lib
lib_suffix=.so
case "$target" in
  *-apple-*) lib_suffix=.dylib ;;
  *-pc-windows-*) lib_prefix=; lib_suffix=.dll ;;
esac

final_suffix=$lib_suffix
case "$target" in
  *-apple-*) final_suffix=.so ;;
esac

source_dir="$project_dir/target/$target/release"
source_file="$source_dir/${lib_prefix}${project_name}${lib_suffix}"
final_name="${lib_prefix}${project_name}-v${project_version}-nif-${nif_version}-${target}${final_suffix}"
archive_name="${final_name}.tar.gz"

if [[ ! -f "$source_file" ]]; then
  echo "missing compiled NIF: $source_file" >&2
  exit 1
fi

cp "$source_file" "$source_dir/$final_name"
tar -C "$source_dir" -czf "$archive_name" "$final_name"

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "file-name=$archive_name"
    echo "file-path=$archive_name"
  } >> "$GITHUB_OUTPUT"
fi

printf 'Packaged %s\n' "$archive_name"
