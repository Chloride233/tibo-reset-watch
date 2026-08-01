#!/bin/zsh
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
app_dir="$project_dir/dist/Tibo Reset Notifier.app"

cd "$project_dir"
swift build -c release

mkdir -p "$app_dir/Contents/MacOS"
cp "$project_dir/.build/release/TiboResetNotifier" "$app_dir/Contents/MacOS/TiboResetNotifier"
cp "$project_dir/Resources/Info.plist" "$app_dir/Contents/Info.plist"
xattr -cr "$app_dir"
codesign --force --sign - "$app_dir"
codesign --verify --deep --strict "$app_dir"

echo "Built: $app_dir"
