#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="staging"
ZIP_DIR="./zips"

mkdir -p "$BASE_DIR"

echo "=== Unstaging Summary ==="
restored=()
skipped=()

for zip_file in "$ZIP_DIR"/*.zip; do
  [ -f "$zip_file" ] || continue
  name=$(basename "$zip_file" .zip)
  target_dir="$BASE_DIR/$name"

  if [ -d "$target_dir" ]; then
    echo "Skipping $zip_file — $target_dir already exists."
    skipped+=("$target_dir")
    continue
  fi

  echo "Unzipping $zip_file into $target_dir..."
  mkdir -p "$target_dir"
  unzip -q "$zip_file" -d "$target_dir"
  restored+=("$target_dir")
done

echo
echo "Restored folders:"
for r in "${restored[@]}"; do echo "  $r"; done
echo "Skipped (already existed):"
for s in "${skipped[@]}"; do echo "  $s"; done
echo "All applicable archives processed."
