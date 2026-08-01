#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
source_app="$project_dir/dist/Tibo Reset Watch.app"
target_dir="$HOME/Applications"
target_app="$target_dir/Tibo Reset Watch.app"

if [[ ! -d "$source_app" ]]; then
    "$project_dir/scripts/build-app.sh"
fi

mkdir -p "$target_dir"
if [[ -d "$target_app" ]]; then
    osascript -e 'tell application id "local.tibo-reset-notifier" to quit' >/dev/null 2>&1 || true
    sleep 1
fi
rm -rf "$target_app"
ditto "$source_app" "$target_app"
xattr -cr "$target_app"
codesign --force --sign - "$target_app"
codesign --verify --deep --strict "$target_app"
open "$target_app"

echo "Installed and launched: $target_app"
