#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR="$SCRIPT_DIR/staging"
ZIP_DIR="$SCRIPT_DIR/zips"

mkdir -p "$ZIP_DIR"

for project_dir in "$BASE_DIR"/*/; do
  [ -d "$project_dir" ] || continue
  project=$(basename "$project_dir")
  zip_path="$ZIP_DIR/$project.zip"

  # Latest file modification time (excluding .git)
  latest_mtime=$(find "$project_dir" -type f \
    \( -path "$project_dir/.git" -prune -o -print \) \
    -printf '%T@\n' | sort -n | tail -1 || echo 0)

  last_zip_time=$(stat -c %Y "$zip_path" 2>/dev/null || echo 0)

  if (($(echo "$latest_mtime <= $last_zip_time" | bc -l))); then
    echo "Processing project: $project, skipping"
    continue
  fi

  echo "Processing project: $project"

  # Initialize git repo if none exists to get ignored files info
  git_repo_created=false
  if [ ! -d "$project_dir/.git" ]; then
    (
      cd "$project_dir"
      git init -q
      git add . >/dev/null 2>&1 || true
    )
    git_repo_created=true
  fi

  # Gather files: tracked + untracked (non-ignored)
  mapfile -d '' tracked_files < <(cd "$project_dir" && git ls-files -z)
  mapfile -d '' untracked_files < <(cd "$project_dir" && git ls-files --others --exclude-standard --no-empty-directory -z)
  files=("${tracked_files[@]}" "${untracked_files[@]}")

  if [ ${#files[@]} -eq 0 ]; then
    echo "No files to zip for project $project, skipping."
    # Clean up temporary git repo
    if $git_repo_created; then rm -rf "$project_dir/.git"; fi
    continue
  fi

  # Remove old zip if exists
  rm -f "$zip_path"

  # Zip all files safely
  (
    cd "$project_dir"
    # Remove leading './' and NUL-terminate safely
    printf '%s\0' "${files[@]}" | sed -z 's|^\./||' | xargs -0 zip -q "$zip_path" || {
      echo "Zip failed for $project" >&2
      exit 1
    }
  )

  # Include .git only if repo existed
  if ! $git_repo_created && [ -d "$project_dir/.git" ]; then
    (
      cd "$project_dir"
      zip -r -q "$zip_path" .git
    )
  fi

  # Cleanup temporary git repo
  if $git_repo_created; then
    rm -rf "$project_dir/.git"
  fi

  echo "Created $zip_path"
done

echo "All projects processed."
