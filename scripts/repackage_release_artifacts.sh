#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <source-version> <target-version> <output-directory>" >&2
  echo "Example: $0 0.4.0 0.4.1 /tmp/ex_rocket-v0.4.1" >&2
  exit 1
fi

source_version="${1#v}"
target_version="${2#v}"
output_directory="$3"
work_directory="$(mktemp -d)"
trap 'rm -rf "$work_directory"' EXIT

mkdir -p "$output_directory" "$work_directory/downloads"

gh release download "v${source_version}" \
  --pattern "*v${source_version}*.tar.gz" \
  --dir "$work_directory/downloads"

artifact_count=0
for source_archive in "$work_directory"/downloads/*.tar.gz; do
  artifact_count=$((artifact_count + 1))
  archive_name="$(basename "$source_archive")"
  target_archive_name="${archive_name/v${source_version}/v${target_version}}"
  unpack_directory="$work_directory/unpack-${artifact_count}"
  mkdir "$unpack_directory"
  tar -xzf "$source_archive" -C "$unpack_directory"

  mapfile_command=(find "$unpack_directory" -mindepth 1 -maxdepth 1 -type f -print)
  if command -v mapfile >/dev/null 2>&1; then
    mapfile -t packaged_files < <("${mapfile_command[@]}")
  else
    packaged_files=()
    while IFS= read -r packaged_file; do
      packaged_files+=("$packaged_file")
    done < <("${mapfile_command[@]}")
  fi

  if [[ ${#packaged_files[@]} -ne 1 ]]; then
    echo "Expected one binary in $archive_name, found ${#packaged_files[@]}" >&2
    exit 1
  fi

  source_binary="${packaged_files[0]}"
  source_binary_name="$(basename "$source_binary")"
  target_binary_name="${source_binary_name/v${source_version}/v${target_version}}"
  mv "$source_binary" "$unpack_directory/$target_binary_name"

  tar -czf "$output_directory/$target_archive_name" \
    -C "$unpack_directory" \
    "$target_binary_name"
  echo "Created $target_archive_name"
done

if [[ $artifact_count -eq 0 ]]; then
  echo "No release artifacts found for v${source_version}" >&2
  exit 1
fi

echo "Repackaged $artifact_count artifacts for v${target_version}"
