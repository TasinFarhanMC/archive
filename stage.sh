#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BASE_DIR="$SCRIPT_DIR/staging"
ZIP_DIR="$SCRIPT_DIR/zips"

mkdir -p "$ZIP_DIR"

for project_dir in "$BASE_DIR"/*/; do
  [ -d "$project_dir" ] || continue
  project=$(basename "$project_dir")

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

  # Use git ls-files to get tracked files
  # Use git ls-files --others --ignored --exclude-standard to get ignored/untracked files
  # We want all tracked files + untracked non-ignored files, so:
  # all_files = tracked files + untracked non-ignored files

  mapfile -d '' tracked_files < <(cd "$project_dir" && git ls-files -z)
  mapfile -d '' untracked_files < <(cd "$project_dir" && git ls-files --others --exclude-standard --no-empty-directory -z)

  # Combine tracked and untracked (non-ignored) files
  files=("${tracked_files[@]}" "${untracked_files[@]}")

  if [ ${#files[@]} -eq 0 ]; then
    echo "No files to zip for project $project, skipping."
    if $git_repo_created; then rm -rf "$project_dir/.git"; fi
    continue
  fi

  zip_path="$ZIP_DIR/$project.zip"
  rm -f "$zip_path"

  (
    cd "$project_dir"
    # zip from the list of files, removing trailing null chars, adjusting path to strip leading './'
    # Remove leading './' from each file path for better zip structure
    printf '%s\0' "${files[@]}" | sed -z 's|^\./||g' | xargs -0 zip -q "$zip_path" || {
      echo "Zip failed for $project" >&2
      exit 1
    }
  )

  echo "Created $zip_path"

  if $git_repo_created; then
    rm -rf "$project_dir/.git"
  fi
done

echo "All projects processed."
